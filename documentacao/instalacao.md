# Instalação, configuração e execução

Os passos valem para **Windows**, **Linux** (Ubuntu/Debian) e **macOS**. O projeto foi
desenvolvido e testado no Windows 11; nos outros sistemas os comandos são os
equivalentes de cada plataforma. Versões exatas: [`versoes.md`](versoes.md).

Convenção: os comandos rodam na **pasta do repositório** (`desafio_dados_2`), salvo
quando indicado. `HOP_HOME` é a pasta onde o Apache Hop foi descompactado
(`C:\hop` no Windows, `~/hop` no Linux e no macOS).

## 1. Pré-requisitos

| Ferramenta | Uso |
|---|---|
| Docker (Desktop no Windows/macOS, Engine no Linux) | PostgreSQL, Superset e OpenMetadata |
| PostgreSQL 16 + pgvector (`desafio-postgres`) | banco do Desafio 1 e de todas as camadas, porta 5432 |
| Java 21 | Apache Hop 2.19 |
| Apache Hop 2.19 | pipelines e workflow ([download](https://hop.apache.org/download/), descompactar em `HOP_HOME`) |
| Python 3.12+ | proteção LGPD e publicação de metadados |

**Windows (PowerShell)**

```powershell
winget install EclipseAdoptium.Temurin.21.JDK
winget install Python.Python.3.12
winget install Docker.DockerDesktop
```

**Linux (Ubuntu/Debian)**

```bash
sudo apt update
sudo apt install -y openjdk-21-jdk python3 python3-pip python3-venv python-is-python3 docker.io docker-compose-v2 unzip
sudo usermod -aG docker $USER   # sair e entrar de novo na sessão
```

**macOS (Homebrew)**

```bash
brew install openjdk@21 python@3.12
brew install --cask docker
```

Se o banco do Desafio 1 não existir na máquina, suba um PostgreSQL com pgvector
(a senha vai também no `.env` e no `dev-secrets.json`):

```bash
docker run -d --name desafio-postgres -p 5432:5432 -e POSTGRES_PASSWORD=<senha> -e POSTGRES_DB=desafio_dados pgvector/pgvector:pg16
```

## 2. Dependências Python

O workflow chama os scripts com o comando **`python`**, então ele precisa existir no PATH
(no Linux o pacote `python-is-python3` cria esse comando).

**Windows**

```powershell
pip install -r requirements.txt
```

**Linux e macOS**

```bash
python3 -m pip install --user -r requirements.txt
```

No Debian/Ubuntu recente o pip do sistema é bloqueado (PEP 668); nesse caso use
`python3 -m pip install --user --break-system-packages -r requirements.txt`.
No macOS, se `python` não existir, crie o atalho com `brew link python@3.12` ou use o
`python3` do Homebrew num alias.

## 3. Apache Hop: plugins e Spark

Plugins, rodando **dentro de `HOP_HOME`**:

**Windows**

```powershell
cd C:\hop
.\hop.bat marketplace install hop-engines-beam
.\hop.bat marketplace install hop-tech-parquet
```

**Linux e macOS**

```bash
cd ~/hop
./hop.sh marketplace install hop-engines-beam
./hop.sh marketplace install hop-tech-parquet
```

O Parquet também precisa de `hadoop-shaded-guava-1.3.0.jar` em `HOP_HOME/lib/core`
(disponível no Maven Central).

Memória e Spark:

**Windows**: o Spark precisa de `winutils.exe` e `hadoop.dll` (Hadoop 3.3.6) em `C:\hadoop\bin`.

```powershell
[Environment]::SetEnvironmentVariable("HOP_OPTIONS", "-Xmx2048m -Dspark.ui.enabled=false -Dhadoop.home.dir=C:\hadoop", "User")
```

**Linux e macOS**: não precisa de winutils. Coloque no `~/.bashrc` (Linux) ou `~/.zshrc` (macOS):

```bash
export HOP_HOME=~/hop
export HOP_OPTIONS="-Xmx2048m -Dspark.ui.enabled=false"
# macOS com Java do Homebrew:
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
```

## 4. Projeto no Hop

Abra o Hop GUI (`C:\hop\hop-gui.bat` no Windows, `~/hop/hop-gui.sh` no Linux e no macOS) e:

1. crie o projeto **`desafio_dados_2`**, com a pasta do repositório como *home*;
2. crie o ambiente **`dev`**, com os arquivos `hop/environments/dev-config.json` e
   `hop/environments/dev-secrets.json`.

## 5. Segredos (fora do Git)

**Windows**

```powershell
Copy-Item .env.example .env
Copy-Item hop/environments/dev-secrets.json.example hop/environments/dev-secrets.json
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

**Linux e macOS**

```bash
cp .env.example .env
cp hop/environments/dev-secrets.json.example hop/environments/dev-secrets.json
openssl rand -base64 32
```

| Arquivo | Preencher |
|---|---|
| `hop/environments/dev-secrets.json` | usuário e senha do PostgreSQL para o Hop |
| `.env` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `OM_JWT_TOKEN`, `LGPD_CHAVE_PSEUDONIMO` e `LGPD_SALT_HASH` (um valor aleatório diferente para cada, gerado pelo último comando acima) |

## 6. Executar a carga completa

O workflow cria sozinho os schemas `bronze`, `silver`, `qualidade`, `gold`, `auditoria`,
`mestre` e `lgpd`.

**Windows**

```powershell
.\scripts\executar_carga_completa.bat
echo "Codigo de saida: $LASTEXITCODE"
```

**Linux e macOS**

```bash
./scripts/executar_carga_completa.sh
echo "Codigo de saida: $?"
```

Conferir início, término, duração e resultado de cada etapa (qualquer sistema):

```bash
docker exec -i desafio-postgres psql -U postgres -d desafio_dados -c "SELECT ordem, etapa, duracao_s, resultado FROM auditoria.vw_duracao_etapas WHERE execucao = (SELECT MAX(inicio_workflow) FROM auditoria.log_etapas);"
```

## 7. Agendamento diário (06:00)

**Windows** (Agendador de Tarefas):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\configurar_agendamento.ps1
```

**Linux e macOS** (cron): rode `crontab -e` e acrescente a linha, trocando o caminho:

```bash
0 6 * * * HOP_HOME=$HOME/hop /caminho/para/desafio_dados_2/scripts/executar_carga_completa.sh
```

## 8. Beam nos três runtimes

Primeiro `exportar_interacoes.hpl` gera o Parquet; depois o mesmo pipeline roda em cada runtime.

**Windows**

```powershell
foreach ($r in "local","beam-direct","spark-local") { C:\hop\hop-run.bat -j desafio_dados_2 -e dev -f "$PWD\hop\pipelines\engajamento_beam.hpl" -r $r }
C:\hop\hop-run.bat -j desafio_dados_2 -e dev -f "$PWD\hop\pipelines\comparar_runtimes.hpl" -r local
```

**Linux e macOS**

```bash
for r in local beam-direct spark-local; do ~/hop/hop-run.sh -j desafio_dados_2 -e dev -f "$PWD/hop/pipelines/engajamento_beam.hpl" -r $r; done
~/hop/hop-run.sh -j desafio_dados_2 -e dev -f "$PWD/hop/pipelines/comparar_runtimes.hpl" -r local
```

## 9. Apache Superset 6.1.0

1. Suba o Superset pelo Docker Compose (o mesmo do Desafio 1). Na pasta do compose,
   `docker/requirements-local.txt` deve conter `psycopg2-binary`, e
   `docker/pythonpath_dev/superset_config.py` deve estar na versão da tag 6.1.0.
2. Crie o usuário de leitura, uma vez:

   **Windows**
   ```powershell
   Get-Content -Encoding UTF8 sql\06_criar_usuario_superset.sql | docker exec -i desafio-postgres psql -U postgres -d desafio_dados
   ```
   **Linux e macOS**
   ```bash
   docker exec -i desafio-postgres psql -U postgres -d desafio_dados < sql/06_criar_usuario_superset.sql
   ```
   Depois, em qualquer sistema:
   ```bash
   docker exec -it desafio-postgres psql -U postgres -d desafio_dados -c "ALTER ROLE superset_leitura PASSWORD '<sua senha>';"
   ```
3. Conexão `desafio_dados_gold`:
   `postgresql+psycopg2://superset_leitura:<senha>@host.docker.internal:5432/desafio_dados`.
   No **Linux**, `host.docker.internal` só existe com `extra_hosts: ["host.docker.internal:host-gateway"]`
   no serviço do Superset; sem isso, use o IP do host (por exemplo `172.17.0.1`).
4. Dashboards → Importar → `superset/exportacao_e_evidencias/painel_executivo_export.zip`.

## 10. OpenMetadata

Instruções da equipe em [`openmetadata/README.md`](../openmetadata/README.md), iguais nos três
sistemas: `docker compose up -d` na pasta `openmetadata`, `python openmetadata/publicar_metadados.py --token`
e as duas ingestões. A partir daí, cada carga publica os metadados sozinha.
