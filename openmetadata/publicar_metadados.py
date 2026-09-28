"""
Publica no OpenMetadata a governança declarada em governanca.yaml
(RF27, RF28, RF29, RF32) — etapa "publicação de metadados" do RF22.

  python openmetadata/publicar_metadados.py            # publica tudo
  python openmetadata/publicar_metadados.py --token    # grava o token do ingestion-bot no .env
  python openmetadata/publicar_metadados.py --auditar  # só verifica (anti Data Swamp)

Idempotente: usa PUT (cria ou atualiza) e JSON Patch; pode rodar sempre.
Credenciais vêm do .env (não versionado). Código de saída:
  0 = sucesso | 1 = falha | 2 = sucesso com ressalvas (ativos pendentes)
"""
import argparse
import base64
import json
import logging
import os
import re
import sys
from pathlib import Path

import requests
import yaml
from dotenv import load_dotenv

RAIZ = Path(__file__).resolve().parent.parent
load_dotenv(RAIZ / ".env")

log = logging.getLogger("publicar_metadados")


# ---------------------------------------------------------------------
# Cliente mínimo da API REST do OpenMetadata
# ---------------------------------------------------------------------
class OM:
    def __init__(self, url, token):
        self.url = url.rstrip("/")
        self.s = requests.Session()
        self.s.headers.update({"Authorization": f"Bearer {token}",
                               "Content-Type": "application/json"})

    @staticmethod
    def login(url, email, senha):
        r = requests.post(f"{url.rstrip('/')}/v1/users/login",
                          json={"email": email,
                                "password": base64.b64encode(senha.encode()).decode()},
                          timeout=30)
        r.raise_for_status()
        return r.json()["accessToken"]

    def get(self, caminho, **params):
        r = self.s.get(f"{self.url}{caminho}", params=params, timeout=60)
        if r.status_code == 404:
            return None
        r.raise_for_status()
        return r.json()

    def put(self, caminho, corpo):
        r = self.s.put(f"{self.url}{caminho}", data=json.dumps(corpo), timeout=60)
        if r.status_code >= 400:
            raise RuntimeError(f"PUT {caminho} -> {r.status_code}: {r.text[:400]}")
        return r.json() if r.content else {}  # /v1/lineage responde sem corpo

    def patch(self, caminho, ops):
        if not ops:
            return None
        r = self.s.patch(f"{self.url}{caminho}", data=json.dumps(ops), timeout=60,
                         headers={"Content-Type": "application/json-patch+json"})
        if r.status_code >= 400:
            raise RuntimeError(f"PATCH {caminho} -> {r.status_code}: {r.text[:400]}")
        return r.json()


def ref(entidade, tipo):
    return {"id": entidade["id"], "type": tipo}


def rotulo(fqn, fonte="Classification"):
    return {"tagFQN": fqn, "source": fonte, "labelType": "Manual", "state": "Confirmed"}


def mesclar_rotulos(atuais, novos):
    """Mantém os rótulos existentes e acrescenta os novos (sem duplicar)."""
    vistos = {t["tagFQN"] for t in atuais or []}
    limpos = [{k: t[k] for k in ("tagFQN", "source", "labelType", "state") if k in t}
              for t in atuais or []]
    return limpos + [n for n in novos if n["tagFQN"] not in vistos]


# ---------------------------------------------------------------------
# Publicação
# ---------------------------------------------------------------------
class Publicador:
    def __init__(self, om, cfg):
        self.om = om
        self.cfg = cfg
        self.donos = {}          # nome -> EntityReference
        self.pipelines = {}      # nome -> entidade
        self.pendentes = []      # ativos não encontrados

    # -- responsáveis ---------------------------------------------------
    def usuarios_e_equipe(self):
        ids = []
        for u in self.cfg["usuarios"]:
            e = self.om.put("/v1/users", {"name": u["nome"], "displayName": u["exibicao"],
                                           "email": u["email"]})
            self.donos[u["nome"]] = ref(e, "user")
            ids.append(e["id"])
        eq = self.cfg["equipe"]
        e = self.om.put("/v1/teams", {"name": eq["nome"], "displayName": eq["exibicao"],
                                       "description": eq["descricao"], "teamType": "Group",
                                       "users": ids})
        self.donos[eq["nome"]] = ref(e, "team")
        log.info("Responsáveis: %d usuários + equipe %s", len(ids), eq["nome"])

    def dono(self, nome):
        return [self.donos[nome]] if nome in self.donos else []

    # -- classificações -------------------------------------------------
    def classificacoes(self):
        for c in self.cfg["classificacoes"]:
            self.om.put("/v1/classifications", {"name": c["nome"], "description": c["descricao"],
                                                 "mutuallyExclusive": c.get("mutuamente_exclusiva", False)})
            for t in c["tags"]:
                self.om.put("/v1/tags", {"name": t["nome"], "description": t["descricao"],
                                         "classification": c["nome"]})
            log.info("Classificação %s: %d tags", c["nome"], len(c["tags"]))

    # -- glossário ------------------------------------------------------
    def glossario(self):
        g = self.cfg["glossario"]
        self.om.put("/v1/glossaries", {"name": g["nome"], "displayName": g["exibicao"],
                                       "description": g["descricao"], "owners": self.dono(g["dono"])})
        for t in g["termos"]:
            descricao = (f"{t['definicao']}\n\n**Regra de cálculo:** `{t['regra']}`\n\n"
                         f"**Responsável:** {t['dono']}")
            self.om.put("/v1/glossaryTerms", {"glossary": g["nome"], "name": t["nome"],
                                              "displayName": t["exibicao"], "description": descricao,
                                              "synonyms": t.get("sinonimos", []),
                                              "owners": self.dono(t["dono"])})
        log.info("Glossário %s: %d termos", g["nome"], len(g["termos"]))

    # -- tabelas --------------------------------------------------------
    def fqn_tabela(self, nome):
        return f"{self.cfg['servico_banco']}.{self.cfg['banco']}.{nome}"

    def buscar_tabela(self, nome):
        return self.om.get(f"/v1/tables/name/{self.fqn_tabela(nome)}", fields="columns,tags,owners")

    def tabelas(self):
        glossario = self.cfg["glossario"]["nome"]
        for nome, t in self.cfg["tabelas"].items():
            tab = self.buscar_tabela(nome)
            if tab is None:
                self.pendentes.append(f"tabela {nome}")
                log.warning("Tabela %s não está no catálogo (ainda não criada/ingerida) — pulada", nome)
                continue
            ops = [{"op": "add", "path": "/description", "value": t["descricao"]}]
            if t.get("dono"):
                ops.append({"op": "add", "path": "/owners", "value": self.dono(t["dono"])})
            novos = [rotulo(f"Camada.{t['camada']}")]
            if t.get("tier"):
                novos.append(rotulo(t["tier"]))
            # tier e camada substituem o valor anterior (mutuamente exclusivos)
            atuais = [x for x in tab.get("tags", [])
                      if not x["tagFQN"].startswith(("Tier.", "Camada."))]
            ops.append({"op": "add", "path": "/tags", "value": mesclar_rotulos(atuais, novos)})

            indice = {c["name"]: (i, c) for i, c in enumerate(tab["columns"])}
            for col, meta in (t.get("colunas") or {}).items():
                if col not in indice:
                    log.warning("  coluna %s.%s não existe — pulada", nome, col)
                    continue
                i, c = indice[col]
                if meta.get("descricao"):
                    ops.append({"op": "add", "path": f"/columns/{i}/description", "value": meta["descricao"]})
                novos = [rotulo(x) for x in meta.get("tags", [])]
                novos += [rotulo(f"{glossario}.{x}", "Glossary") for x in meta.get("termos", [])]
                if novos:
                    ops.append({"op": "add", "path": f"/columns/{i}/tags",
                                "value": mesclar_rotulos(c.get("tags"), novos)})
            self.om.patch(f"/v1/tables/{tab['id']}", ops)
            log.info("Tabela %s: descrição, dono, %d colunas anotadas", nome, len(t.get("colunas") or {}))

    # -- arquivos, Hop e Superset (ativos fora do PostgreSQL) ------------
    def arquivos(self):
        a = self.cfg["arquivos"]
        self.om.put("/v1/services/storageServices", {
            "name": a["servico"], "serviceType": "CustomStorage", "description": a["descricao"],
            "connection": {"config": {"type": "CustomStorage"}}, "owners": self.dono(a["dono"])})
        for i in a["itens"]:
            self.om.put("/v1/containers", {
                "name": i["nome"], "service": a["servico"], "fileFormats": [i["formato"]],
                "fullPath": i["caminho"], "description": i["descricao"],
                "owners": self.dono(a["dono"]),
                "tags": [rotulo(f"Camada.{i.get('camada', 'Fonte')}")]})
        log.info("Arquivos (fontes e Parquet): %d", len(a["itens"]))

    def hop(self):
        h = self.cfg["hop"]
        self.om.put("/v1/services/pipelineServices", {
            "name": h["servico"], "serviceType": "CustomPipeline", "description": h["descricao"],
            "connection": {"config": {"type": "CustomPipeline"}}, "owners": self.dono(h["dono"])})
        for p in h["pipelines"]:
            self.pipelines[p["nome"]] = self.om.put("/v1/pipelines", {
                "name": p["nome"], "service": h["servico"], "description": p["descricao"],
                "owners": self.dono(h["dono"])})
        log.info("Pipelines Hop: %d", len(h["pipelines"]))

    def superset(self):
        s = self.cfg["superset"]
        srv = s["servico"]
        self.om.put("/v1/services/dashboardServices", {
            "name": srv, "serviceType": "CustomDashboard", "description": s["descricao"],
            "connection": {"config": {"type": "CustomDashboard"}}, "owners": self.dono(s["dono"])})
        for d in s["datasets_virtuais"]:
            sql = ""
            arq = RAIZ / d["sql_arquivo"]
            if arq.exists():
                sql = arq.read_text(encoding="utf-8")
            self.om.put("/v1/dashboard/datamodels", {
                "name": d["nome"], "service": srv, "dataModelType": "SupersetDataModel",
                "description": d["descricao"], "sql": sql, "columns": [],
                "owners": self.dono(s["dono"])})
        for g in s["graficos"]:
            self.om.put("/v1/charts", {"name": g["nome"], "service": srv,
                                       "chartType": g["tipo"], "description": g["descricao"]})
        for d in s["dashboards"]:
            self.om.put("/v1/dashboards", {
                "name": d["nome"], "displayName": d["exibicao"], "service": srv,
                "description": d["descricao"], "owners": self.dono(s["dono"]),
                "charts": [f"{srv}.{g}" for g in d["graficos"]],
                "dataModels": [f"{srv}.model.{m}" for m in d["datasets"]],
                "tags": [rotulo("Camada.Gold")]})
        log.info("Superset: %d datasets virtuais, %d gráficos, %d dashboards",
                 len(s["datasets_virtuais"]), len(s["graficos"]), len(s["dashboards"]))

    # -- linhagem manual ------------------------------------------------
    def resolver(self, ponta):
        tipo, nome = ponta.split(":", 1)
        if tipo == "tabela":
            e = self.om.get(f"/v1/tables/name/{self.fqn_tabela(nome)}")
            return (ref(e, "table") if e else None)
        if tipo == "arquivo":
            e = self.om.get(f"/v1/containers/name/{self.cfg['arquivos']['servico']}.\"{nome}\"")
            return (ref(e, "container") if e else None)
        srv = self.cfg["superset"]["servico"]
        if tipo == "dataset":
            e = self.om.get(f"/v1/dashboard/datamodels/name/{srv}.model.{nome}")
            return (ref(e, "dashboardDataModel") if e else None)
        if tipo == "dashboard":
            e = self.om.get(f"/v1/dashboards/name/{srv}.{nome}")
            return (ref(e, "dashboard") if e else None)
        raise ValueError(f"Tipo de ponta desconhecido: {ponta}")

    def linhagem(self):
        criadas = 0
        for a in self.cfg["linhagem"]:
            de, para = self.resolver(a["de"]), self.resolver(a["para"])
            if not de or not para:
                self.pendentes.append(f"linhagem {a['de']} -> {a['para']}")
                log.warning("Linhagem %s -> %s pulada (ponta ainda não existe)", a["de"], a["para"])
                continue
            detalhes = {"description": a.get("descricao", ""), "source": "Manual"}
            if a.get("via") in self.pipelines:
                detalhes["pipeline"] = ref(self.pipelines[a["via"]], "pipeline")
            self.om.put("/v1/lineage", {"edge": {"fromEntity": de, "toEntity": para,
                                                 "lineageDetails": detalhes}})
            criadas += 1
        log.info("Linhagem manual: %d arestas", criadas)

    def executar(self):
        self.usuarios_e_equipe()
        self.classificacoes()
        self.glossario()
        self.tabelas()
        self.arquivos()
        self.hop()
        self.superset()
        self.linhagem()


# ---------------------------------------------------------------------
# Auditoria anti Data Swamp (RF27): todo ativo catalogado precisa de
# descrição e responsável; campos pessoais precisam de classificação LGPD.
# ---------------------------------------------------------------------
def auditar(om, cfg):
    problemas = []
    servico = f"{cfg['servico_banco']}.{cfg['banco']}"
    depois = None
    while True:
        params = {"database": servico, "fields": "owners,tags,columns", "limit": 100}
        if depois:
            params["after"] = depois
        pag = om.get("/v1/tables", **params) or {"data": [], "paging": {}}
        for t in pag["data"]:
            if t["fullyQualifiedName"].split(".")[2] not in ("bronze", "silver", "gold", "qualidade"):
                continue
            nome = ".".join(t["fullyQualifiedName"].split(".")[2:])
            if not t.get("description"):
                problemas.append(f"{nome}: sem descrição")
            if not t.get("owners"):
                problemas.append(f"{nome}: sem responsável")
            for c in t["columns"]:
                if re.fullmatch(r"usuario_id|autor|comentario|email|nome", c["name"]) and \
                        not any(x["tagFQN"].startswith("LGPD.") for x in c.get("tags", [])):
                    problemas.append(f"{nome}.{c['name']}: possível dado pessoal sem classificação LGPD")
        depois = pag.get("paging", {}).get("after")
        if not depois:
            break
    for p in problemas:
        log.warning("AUDITORIA: %s", p)
    log.info("Auditoria: %d problema(s)", len(problemas))
    return problemas


def gravar_token_bot(url, token_admin):
    om = OM(url, token_admin)
    bot = om.get("/v1/bots/name/ingestion-bot", fields="botUser")
    usuario = om.get(f"/v1/users/auth-mechanism/{bot['botUser']['id']}")
    jwt = usuario["config"]["JWTToken"]
    env = RAIZ / ".env"
    texto = env.read_text(encoding="utf-8") if env.exists() else ""
    if re.search(r"^OM_JWT_TOKEN=.*$", texto, flags=re.M):
        texto = re.sub(r"^OM_JWT_TOKEN=.*$", f"OM_JWT_TOKEN={jwt}", texto, flags=re.M)
    else:
        texto += f"\nOM_JWT_TOKEN={jwt}\n"
    env.write_text(texto, encoding="utf-8")
    log.info("Token do ingestion-bot gravado em %s (arquivo não versionado)", env)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default=str(Path(__file__).with_name("governanca.yaml")))
    ap.add_argument("--token", action="store_true", help="grava o JWT do ingestion-bot no .env")
    ap.add_argument("--auditar", action="store_true", help="só executa a auditoria anti Data Swamp")
    ap.add_argument("--id-execucao", default=os.getenv("ID_EXECUCAO", "manual"))
    args = ap.parse_args()

    logging.basicConfig(level=logging.INFO,
                        format=f"%(asctime)s [{args.id_execucao}] %(levelname)s %(message)s")
    url = os.getenv("OM_URL", "http://localhost:8585/api")
    try:
        token = OM.login(url, os.getenv("OM_ADMIN_EMAIL", "admin@open-metadata.org"),
                         os.getenv("OM_ADMIN_PASSWORD", "admin"))
    except requests.RequestException as e:
        log.error("Não foi possível autenticar no OpenMetadata em %s: %s", url, e)
        return 1

    if args.token:
        gravar_token_bot(url, token)
        return 0

    cfg = yaml.safe_load(Path(args.config).read_text(encoding="utf-8"))
    om = OM(url, token)
    if args.auditar:
        return 2 if auditar(om, cfg) else 0

    pub = Publicador(om, cfg)
    try:
        pub.executar()
    except Exception as e:  # noqa: BLE001 — falha crítica: registra e sinaliza ao workflow
        log.error("Falha na publicação de metadados: %s", e)
        return 1
    problemas = auditar(om, cfg)
    if pub.pendentes or problemas:
        log.warning("SUCESSO COM RESSALVAS: %d ativo(s) pendente(s), %d problema(s) de auditoria",
                    len(pub.pendentes), len(problemas))
        return 2
    log.info("SUCESSO: metadados publicados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
