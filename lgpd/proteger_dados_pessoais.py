"""
Protecao de dados pessoais (RF32 / RF33) - etapa do workflow carga_completa.

  python lgpd/proteger_dados_pessoais.py                          # gera/protege tudo
  python lgpd/proteger_dados_pessoais.py --verificar-email X@Y    # comparacao por hash

O que faz:
  1. cria o schema lgpd (sql/09_criar_tabelas_lgpd.sql);
  2. gera um cadastro FICTICIO para os usuarios de public.usuario que ainda nao
     tem cadastro (nada de dado real; CPF com digito verificador invalido);
  3. PSEUDONIMIZA o usuario_id com HMAC-SHA256 + chave secreta
     (LGPD_CHAVE_PSEUDONIMO) e grava a tabela de correspondencia em lgpd;
  4. aplica HASH SHA-256 com salt (LGPD_SALT_HASH) ao e-mail;
  5. MASCARA nome e e-mail e generaliza a data de nascimento em faixa etaria;
  6. grava lgpd.usuario_protegido, lido pela Gold.

Segredos vem do .env (nao versionado). Codigo de saida: 0 = sucesso | 1 = falha.
"""
import argparse
import hashlib
import hmac
import os
import random
import sys
import unicodedata
from datetime import date, timedelta
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

RAIZ = Path(__file__).resolve().parent.parent
load_dotenv(RAIZ / ".env")
DDL = RAIZ / "sql" / "09_criar_tabelas_lgpd.sql"

# ---------------------------------------------------------------------
# Listas para o cadastro ficticio
# ---------------------------------------------------------------------
NOMES = ["Ana", "Bruno", "Camila", "Diego", "Eduarda", "Felipe", "Gabriela", "Henrique",
         "Isabela", "Joao", "Larissa", "Marcos", "Natalia", "Otavio", "Paula", "Rafael",
         "Sabrina", "Tiago", "Vanessa", "Wagner", "Yasmin", "Lucas", "Beatriz", "Caio"]
SOBRENOMES = ["Almeida", "Barros", "Costa", "Duarte", "Esteves", "Fontes", "Guimaraes",
              "Moreira", "Nogueira", "Oliveira", "Pinheiro", "Queiroz", "Rocha", "Silveira",
              "Teixeira", "Vasconcelos", "Martins", "Ramos", "Toledo", "Borges"]
CIDADES = [("Cuiaba", "MT"), ("Varzea Grande", "MT"), ("Rondonopolis", "MT"), ("Sinop", "MT"),
           ("Campo Grande", "MS"), ("Goiania", "GO"), ("Brasilia", "DF"), ("Sao Paulo", "SP")]
ACESSIBILIDADE = ["baixa visao", "deficiencia auditiva", "mobilidade reduzida"]


def conectar():
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "localhost"),
        port=os.getenv("POSTGRES_PORT", "5432"),
        dbname=os.getenv("POSTGRES_DB", "desafio_dados"),
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    )


def segredo(nome):
    valor = os.getenv(nome, "").strip()
    if len(valor) < 16:
        sys.exit(f"ERRO: defina {nome} no .env (minimo 16 caracteres).")
    return valor.encode("utf-8")


def sem_acento(txt):
    return "".join(c for c in unicodedata.normalize("NFD", txt) if unicodedata.category(c) != "Mn")


def cpf_ficticio(rnd):
    """9 digitos aleatorios + digitos verificadores ERRADOS de proposito:
    o numero tem formato de CPF, mas nunca e um CPF valido (logo, nunca real)."""
    base = [rnd.randint(0, 9) for _ in range(9)]
    for peso in (10, 11):
        soma = sum(d * (peso - i) for i, d in enumerate(base))
        dv = (soma * 10 % 11) % 10
        base.append((dv + 1) % 10)          # digito propositalmente invalido
    s = "".join(map(str, base))
    return f"{s[:3]}.{s[3:6]}.{s[6:9]}-{s[9:]}"


def cadastro_ficticio(usuario_id):
    rnd = random.Random(usuario_id)          # deterministico: sempre o mesmo cadastro
    nome = " ".join([rnd.choice(NOMES)] + rnd.sample(SOBRENOMES, 2))
    partes = sem_acento(nome).lower().split()
    email = f"{partes[0]}.{partes[-1]}{usuario_id}@exemplo.com"   # dominio reservado (RFC 2606)
    nascimento = date(1965, 1, 1) + timedelta(days=rnd.randint(0, 15000))
    cidade, uf = rnd.choice(CIDADES)
    acess = rnd.choice(ACESSIBILIDADE) if rnd.random() < 0.08 else None
    return (usuario_id, nome, email, cpf_ficticio(rnd),
            f"(65) 90000-{rnd.randint(0, 9999):04d}",   # faixa ficticia
            nascimento, cidade, uf, acess,
            date(2024, 1, 1) + timedelta(days=rnd.randint(0, 700)))


# ---------------------------------------------------------------------
# Tecnicas de protecao
# ---------------------------------------------------------------------
def pseudonimizar(usuario_id, chave):
    """HMAC-SHA256: sem a chave nao se recalcula nem se reverte o pseudonimo;
    a associacao controlada e feita pela tabela lgpd.usuario_pseudonimo."""
    return "U" + hmac.new(chave, str(usuario_id).encode(), hashlib.sha256).hexdigest()[:16]


def hash_com_salt(valor, salt):
    """SHA-256 com salt: irreversivel, serve so para comparar (mesmo valor -> mesmo hash)."""
    return hashlib.sha256(salt + valor.strip().lower().encode("utf-8")).hexdigest()


def mascarar_nome(nome):
    return " ".join(p[0] + "*" * (len(p) - 1) for p in nome.split())


def mascarar_email(email):
    usuario, dominio = email.split("@", 1)
    return f"{usuario[0]}*****@{dominio}"


def faixa_etaria(nascimento, hoje):
    idade = hoje.year - nascimento.year - ((hoje.month, hoje.day) < (nascimento.month, nascimento.day))
    for limite, faixa in ((24, "18-24"), (34, "25-34"), (44, "35-44"), (59, "45-59")):
        if idade <= limite:
            return faixa
    return "60+"


# ---------------------------------------------------------------------
def proteger():
    chave = segredo("LGPD_CHAVE_PSEUDONIMO")
    salt = segredo("LGPD_SALT_HASH")
    with conectar() as con, con.cursor() as cur:
        cur.execute(DDL.read_text(encoding="utf-8"))

        cur.execute("""SELECT u.usuario_id FROM public.usuario u
                       LEFT JOIN lgpd.usuario_cadastro c ON c.usuario_id = u.usuario_id
                       WHERE c.usuario_id IS NULL""")
        novos = [cadastro_ficticio(r[0]) for r in cur.fetchall()]
        cur.executemany("INSERT INTO lgpd.usuario_cadastro VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)", novos)

        cur.execute("SELECT usuario_id, nome, email, data_nascimento, uf FROM lgpd.usuario_cadastro")
        cadastro = cur.fetchall()
        hoje = date.today()

        cur.execute("TRUNCATE lgpd.usuario_pseudonimo, lgpd.usuario_protegido")
        pseudo = [(uid, pseudonimizar(uid, chave)) for uid, *_ in cadastro]
        cur.executemany("INSERT INTO lgpd.usuario_pseudonimo (usuario_id, pseudonimo) VALUES (%s,%s)", pseudo)
        mapa = dict(pseudo)
        cur.executemany(
            """INSERT INTO lgpd.usuario_protegido
               (pseudonimo, nome_mascarado, email_mascarado, email_hash, faixa_etaria, uf)
               VALUES (%s,%s,%s,%s,%s,%s)""",
            [(mapa[uid], mascarar_nome(nome), mascarar_email(email), hash_com_salt(email, salt),
              faixa_etaria(nasc, hoje), uf) for uid, nome, email, nasc, uf in cadastro])

    print(f"LGPD: {len(novos)} cadastros ficticios novos; "
          f"{len(cadastro)} usuarios pseudonimizados, mascarados e com e-mail em hash.")


def verificar_email(email):
    """Comparacao irreversivel: calcula o hash do e-mail informado e procura na base,
    sem nunca ler o e-mail original."""
    salt = segredo("LGPD_SALT_HASH")
    with conectar() as con, con.cursor() as cur:
        cur.execute("SELECT pseudonimo, email_mascarado FROM lgpd.usuario_protegido WHERE email_hash = %s",
                    (hash_com_salt(email, salt),))
        achado = cur.fetchone()
    print(f"hash = {hash_com_salt(email, salt)}")
    print(f"ENCONTRADO: pseudonimo {achado[0]} ({achado[1]})" if achado else "NAO encontrado")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--verificar-email")
    args = ap.parse_args()
    try:
        verificar_email(args.verificar_email) if args.verificar_email else proteger()
    except Exception as erro:          # noqa: BLE001 - qualquer falha deve parar a carga
        print(f"ERRO na protecao de dados pessoais: {erro}", file=sys.stderr)
        sys.exit(1)