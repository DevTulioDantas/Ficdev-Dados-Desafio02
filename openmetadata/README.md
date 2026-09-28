# OpenMetadata — catálogo, glossário, classificação e linhagem (RF27–RF29, RF32)

Versão: **OpenMetadata 1.13.6** (servidor) + **openmetadata-ingestion 1.13.6.3** (CLI).

## Como funciona

| Peça | O que faz | Onde |
|---|---|---|
| `docker-compose.yml` | Sobe servidor OM + Postgres interno + Elasticsearch | derivado do compose oficial 1.13.6 |
| `ingestao/postgres_desafio.yaml` | Ingestão **automática** dos metadados técnicos (schemas, tabelas, colunas, tipos, views) | container `ingestao` |
| `ingestao/postgres_linhagem.yaml` | Linhagem **automática** extraída do SQL das views (ex.: Gold criada como VIEW sobre a Silver) | container `ingestao` |
| `governanca.yaml` | Metadados de **negócio** como código: responsáveis, descrições, glossário, classificações LGPD, camadas, tiers, ativos fora do banco e linhagem manual | versionado |
| `publicar_metadados.py` | Aplica o `governanca.yaml` na API do OM (idempotente) e faz a **auditoria anti Data Swamp** | Python local |

Diferenças em relação ao compose oficial (para caber em máquinas com ~8 GB de RAM):

- sem o container `ingestion` (Airflow, ~1,5 GB): a ingestão roda **sob demanda** e o container é removido ao terminar;
- Postgres interno do OM **sem porta no host** (a 5432 já é do `desafio-postgres`);
- heap do Elasticsearch 512 MB e do servidor 512 MB–1 GB. Uso medido: ~2,1 GB no total.

## Passo a passo (primeira vez)

Pré-requisitos: Docker Desktop aberto, `desafio-postgres` rodando e o workflow `carga_completa`
executado ao menos uma vez (para existirem os schemas bronze/silver/qualidade).

```powershell
# 0) na raiz do projeto: .env criado a partir do .env.example e dependências Python
pip install -r requirements.txt

# 1) subir o OpenMetadata (1ª vez baixa ~2 GB de imagens; depois ~2 min)
cd openmetadata
docker compose up -d
# UI: http://localhost:8585  —  login: admin@open-metadata.org / admin

# 2) gravar no .env o token JWT do ingestion-bot (não versionado)
cd ..
python openmetadata/publicar_metadados.py --token

# 3) ingestão dos metadados técnicos do PostgreSQL
cd openmetadata
docker compose run --rm ingestao metadata ingest -c /config/postgres_desafio.yaml

# 4) linhagem automática das views de KPI da Gold (gold.vw_kpi_* -> fatos/dimensões)
docker compose run --rm ingestao metadata ingest -c /config/postgres_linhagem.yaml

# 5) publicar governança: donos, descrições, glossário, tags, linhagem manual
cd ..
python openmetadata/publicar_metadados.py
```

> No Git Bash, prefixe os comandos `docker compose run` com `MSYS_NO_PATHCONV=1`
> para ele não converter `/config/...` em caminho do Windows.

Códigos de saída do `publicar_metadados.py` (para usar no workflow do Hop — RF22):
`0` sucesso · `2` sucesso com ressalvas (ativos pendentes / auditoria) · `1` falha.

Rodadas seguintes: depois de cada carga, repita os passos **3** e **5**
(e o **4**, se houver views novas). Tudo é idempotente.

## O que está catalogado

- **Serviço `pg_desafio`** (PostgreSQL): schemas `public` (fonte do Desafio 1), `bronze`, `silver`
  (inclui a quarentena `rejeitados_*`), `qualidade` e `gold` (modelo estrela `dim_conteudo`, `dim_usuario`, `fato_interacoes`, `fato_recomendacao` + views `vw_kpi_*`).
- **Serviço `arquivos_desafio1`** (armazenamento): fontes `catalogo_conteudos.csv`, `interacoes_usuarios.json`,
  `comentarios_avaliacoes.json` + arquivos gerados `interacoes_usuarios.snappy.parquet`, `interacoes_usuarios.csv`
  (RF24) e `engajamento_por_tipo` (saída do Beam, RF25).
- **Serviço `hop_desafio`** (pipelines): o workflow `carga_completa`, os pipelines Bronze/Silver/Gold,
  `exportar_interacoes` e `engajamento_beam`.
  Cada aresta de linhagem aponta o pipeline Hop que fez a transformação.
- **Serviço `superset_desafio`** (dashboards): datasets virtuais do SQL Lab, gráficos (KPIs) e o
  `painel_executivo`. ⚠️ Os nomes estão em `governanca.yaml > superset` e devem ser ajustados aos
  nomes reais criados no Superset.

### Glossário `GlossarioEducacional` (RF28)

| Termo | Regra de cálculo | Responsável |
|---|---|---|
| Usuário ativo | `COUNT(DISTINCT usuario_id)` de interações válidas no período | Libia |
| Taxa de conclusão | `100 * interações com percentual_conclusao >= 100 / interações com percentual informado` | Gabriele |
| Conversão de recomendação | `100 * recomendações seguidas de interação do mesmo usuário no mesmo conteúdo / recomendações geradas` | Gabriele |
| Avaliação média | `AVG(avaliacao)` com notas de 1 a 5 | Túlio |
| Taxa de quarentena | `100 * rejeitados / lidos da Bronze` por execução | Túlio |
| Identificador da execução | UUID do workflow gravado em todas as camadas | Túlio |

Os termos estão associados às colunas correspondentes (ex.: `silver.interacoes_usuarios.usuario_id`
→ *Usuário ativo*; `percentual_conclusao` → *Taxa de conclusão*).

### Classificações (RF28, RF32)

- **`LGPD`** (mutuamente exclusiva): `DadoPessoal`, `DadoPessoalSensivel`, `IdentificadorIndireto`,
  `TextoLivre`, `Pseudonimizado`, `Mascarado`, `HashComSalt`, `NaoPessoal`.
- **`Camada`**: `Fonte`, `Bronze`, `Silver`, `Quarentena`, `Gold`, `Qualidade`.
- Nativas do OM: `PII.Sensitive` / `PII.NonSensitive` e `Tier.Tier1` (Gold) … `Tier.Tier4` (Bronze).

Campos classificados: `autor` → DadoPessoal; `usuario_id` → IdentificadorIndireto;
`comentario` → TextoLivre + PII.Sensitive (não vai para a Gold).

## Linhagem (RF29)

```
arquivos CSV/JSON ─┐                         ┌─> silver.<tabela> ─(Hop gold_*)─> gold.fato_*/dim_* ─(view)─> gold.vw_kpi_*
public.recomendacao┴─> bronze.<tabela> ─(Hop)┤                                                                  │
                                             └─> silver.rejeitados_<tabela> (quarentena)                         v
silver.interacoes_usuarios ─(exportar_interacoes)─> Parquet ─(engajamento_beam)─> engajamento_por_tipo   dataset virtual (SQL Lab)
                                                                                                                │
                                                                                                       painel_executivo
```

- **Automática**: tabelas/colunas (ingestão) e views `gold.vw_kpi_*` → fatos/dimensões (`postgres_linhagem.yaml`).
- **Manual** (não extraível: arquivos, pipelines Hop, Superset): declarada em `governanca.yaml > linhagem`.

**Como localizar a origem de um valor do dashboard:** abra o `painel_executivo` no OM → aba
*Lineage* → siga para trás: dataset virtual → tabela Gold (regra de cálculo na descrição e no termo
do glossário) → Silver (o pipeline Hop da aresta mostra a transformação) → Bronze
(`origem`, `data_hora_ingestao`, `id_execucao`) → arquivo-fonte.

## Controles contra o Data Swamp (RF27)

1. **Nada entra sem dono e descrição**: a auditoria (`--auditar`, também roda ao fim da publicação)
   lista tabelas das camadas sem responsável/descrição e devolve "sucesso com ressalvas".
2. **Dado pessoal sem classificação é apontado**: colunas como `usuario_id`, `autor`, `comentario`
   sem tag `LGPD.*` aparecem na auditoria.
3. **Ingestão filtrada**: só os schemas do projeto (`schemaFilterPattern`) — nada de tabelas soltas.
4. **Tabelas apagadas são marcadas** (`markDeletedTables`), evitando ativos "fantasma".
5. **Camada e Tier em todo ativo**: deixa claro o que é bruto (Bronze, Tier4) e o que é confiável
   para consumo (Gold, Tier1).
6. **Glossário com regra e responsável**: um KPI só tem um significado.
7. **Governança como código**: `governanca.yaml` é revisado no Git; a publicação é repetível.

## Evidências (RF34)

Capturas em `openmetadata/evidencias/`:

- [ ] lista de tabelas do serviço `pg_desafio` com donos e tiers
- [ ] uma tabela Silver mostrando colunas com tags LGPD e termos do glossário
- [ ] glossário `GlossarioEducacional` com os termos
- [ ] classificação `LGPD` com as tags
- [ ] linhagem de `silver.interacoes_usuarios` (arquivo → Bronze → Silver)
- [ ] linhagem de ponta a ponta até o `painel_executivo` (ex.: a partir de `gold.vw_kpi_recomendacao`)
- [ ] saída do `publicar_metadados.py` (log com o id_execucao)
