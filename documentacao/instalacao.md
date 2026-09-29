# Instalação, configuração e execução

Ambiente de referência: Windows 11, PowerShell, Docker Desktop.
Versões exatas de cada ferramenta: [`versoes.md`](versoes.md).

## 1. Pré-requisitos

| Ferramenta | Uso | Observação |
|---|---|---|
| Docker Desktop | PostgreSQL, Superset e OpenMetadata | aberto antes de tudo |
| PostgreSQL + pgvector (`desafio-postgres`) | banco do Desafio 1 e de todas as camadas | container do Desafio 1, porta 5432 |
| Java 21 | Apache Hop 2.19 | apontado por `HOP_JAVA_HOME` |
| Apache Hop 2.19 | pipelines e workflow | instalado em `C:\hop` |
| Python 3.12+ | proteção LGPD e publicação de metadados | `pip install -r requirements.txt` |

## 2. Apache Hop

1. Plugins, pelo Marketplace (na pasta `C:\hop`):
   ```powershell
   .\hop.bat marketplace install hop-engines-beam
   .\hop.bat marketplace install hop-tech-parquet
   ```
   O Parquet também precisa de `hadoop-shaded-guava-1.3.0.jar` em `C:\hop\lib\core`.
2. Spark no Windows: `winutils.exe` e `hadoop.dll` (Hadoop 3.3.6) em `C:\hadoop\bin`, e a variável de usuário
   `HOP_OPTIONS = -Xmx2048m -Dspark.ui.enabled=false -Dhadoop.home.dir=C:\hadoop`.
3. Projeto: no Hop GUI, crie o projeto **`desafio_dados_2`** com a pasta do repositório como *home*
   e o ambiente **`dev`** com os arquivos `hop/environments/dev-config.json` e `hop/environments/dev-secrets.json`.

## 3. Segredos (fora do Git)

```powershell
Copy-Item .env.example .env
Copy-Item hop/environments/dev-secrets.json.example hop/environments/dev-secrets.json
```

| Arquivo | Preencher |
|---|---|
| `hop/environments/dev-secrets.json` | usuário e senha do PostgreSQL para o Hop |
| `.env` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `OM_JWT_TOKEN`, `LGPD_CHAVE_PSEUDONIMO` e `LGPD_SALT_HASH` (32+ caracteres aleatórios cada) |

Gerar chave e salt:

```powershell
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

## 4. Primeira carga

```powershell
pip install -r requirements.txt
.\scripts\executar_carga_completa.bat
echo "Codigo de saida: $LASTEXITCODE"
```

O workflow cria sozinho todos os schemas e tabelas (`bronze`, `silver`, `qualidade`, `gold`,
`auditoria`, `mestre`, `lgpd`). Conferir a duração e o resultado de cada etapa:

```powershell
docker exec -i desafio-postgres psql -U postgres -d desafio_dados -c "SELECT ordem, etapa, duracao_s, resultado FROM auditoria.vw_duracao_etapas WHERE execucao = (SELECT MAX(inicio_workflow) FROM auditoria.log_etapas);"
```

Agendamento diário (06:00, Agendador de Tarefas do Windows):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\configurar_agendamento.ps1
```

## 5. Beam nos três runtimes

```powershell
C:\hop\hop-run.bat -j desafio_dados_2 -e dev -f "$PWD\hop\pipelines\engajamento_beam.hpl" -r local
C:\hop\hop-run.bat -j desafio_dados_2 -e dev -f "$PWD\hop\pipelines\engajamento_beam.hpl" -r beam-direct
C:\hop\hop-run.bat -j desafio_dados_2 -e dev -f "$PWD\hop\pipelines\engajamento_beam.hpl" -r spark-local
C:\hop\hop-run.bat -j desafio_dados_2 -e dev -f "$PWD\hop\pipelines\comparar_runtimes.hpl" -r local
```

Antes, `exportar_interacoes.hpl` gera o Parquet de entrada.

## 6. Apache Superset 6.1.0

1. Suba o Superset (Docker Compose do Desafio 1). Dois ajustes na pasta do compose:
   `docker/requirements-local.txt` com `psycopg2-binary`, e `docker/pythonpath_dev/superset_config.py`
   na versão da tag 6.1.0.
2. Usuário de leitura, uma vez:
   ```powershell
   Get-Content -Encoding UTF8 sql\06_criar_usuario_superset.sql | docker exec -i desafio-postgres psql -U postgres -d desafio_dados
   docker exec -it desafio-postgres psql -U postgres -d desafio_dados -c "ALTER ROLE superset_leitura PASSWORD '<sua senha>';"
   ```
3. Conexão `desafio_dados_gold`: `postgresql+psycopg2://superset_leitura:<senha>@host.docker.internal:5432/desafio_dados`.
4. Dashboards → Importar → `superset/exportacao_e_evidencias/painel_executivo_export.zip`.

## 7. OpenMetadata

Instruções da equipe em [`openmetadata/README.md`](../openmetadata/README.md): subir com
`docker compose up -d`, gravar o token com `python openmetadata/publicar_metadados.py --token`
e rodar as duas ingestões. Depois disso, cada carga publica os metadados sozinha.
