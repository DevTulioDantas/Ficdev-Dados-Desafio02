# Desafio Prático 2 — Pipeline Governado, Escalável e Seguro de Conteúdos Educacionais

Fundamentos de Dados para IA — FIC_DEV

Continuação do [Desafio Prático 1](https://github.com/DevTulioDantas/-Ficdev-Dados-Desafio01).

## Equipe

Integrantes:
Túlio Dantas
Líbia Canete
Gabriele Silva

## Status

| Requisito | Descrição | Status | Documentação e evidências |
|---|---|---|---|
| RF15 | Continuidade e configuração | ✅ | [`versoes.md`](documentacao/versoes.md) |
| RF16–RF18 | Storytelling, SQL Lab, filtros e alertas | ✅ | [`narrativa_executiva.md`](documentacao/narrativa_executiva.md), [`sql_lab.sql`](sql/sql_lab.sql), [`superset/exportacao_e_evidencias/`](superset/exportacao_e_evidencias/) |
| RF19 | Arquitetura ETL/ELT | ✅ | [`rf19_arquitetura_etl_elt.md`](documentacao/rf19_arquitetura_etl_elt.md) |
| RF20 | Pipeline Bronze | ✅ | `hop/pipelines/bronze_*.hpl` |
| RF21 | Pipeline Silver | ✅ | [`rf21_regras_silver.md`](documentacao/rf21_regras_silver.md) |
| RF22 | Workflow e orquestração | ✅ | `hop/workflows/carga_completa.hwf`, `documentacao/evidencias/rf22_*.txt` |
| RF23 | Erros e quarentena | ✅ | `documentacao/evidencias/rf23_*.txt` |
| RF24–RF25 | Parquet e Apache Beam | ✅ | [`beam/evidencias/`](beam/evidencias/) |
| RF26 | Camada Gold | ✅ | `sql/05_criar_tabelas_gold.sql`, `documentacao/evidencias/rf26_*.txt` |
| RF27–RF29 | OpenMetadata: catálogo, glossário, linhagem | ✅ publicação automática ·  | [`openmetadata/`](openmetadata/) |
| RF30 | Dados mestres | ✅ | [`rf30_dados_mestres.md`](documentacao/rf30_dados_mestres.md) |
| RF31 | Qualidade | ✅ | `documentacao/evidencias/rf31_resultados_qualidade.txt` |
| RF32–RF33 | LGPD | ✅ | [`rf32_rf33_lgpd.md`](documentacao/rf32_rf33_lgpd.md) |
| RF34 | Evidências | ✅ (pendências marcadas no índice) | [`rf34_evidencias.md`](documentacao/rf34_evidencias.md) |

## Configuração (RF15)

Parâmetros ficam **fora** dos pipelines; segredos ficam **fora** do repositório.

| Arquivo | O que guarda | Versionado? |
|---|---|---|
| `config.json` | caminhos, schemas, nomes (scripts Python) | ✅ sim |
| `hop/environments/dev-config.json` | variáveis do ambiente Hop `dev` | ✅ sim |
| `hop/environments/dev-secrets.json` | usuário/senha do banco para o Hop | ❌ não (modelo: `.example`) |
| `.env` | senha do PostgreSQL, token do OpenMetadata, chave de pseudonimização e salt da LGPD | ❌ não (modelo: `.env.example`) |

### Primeira configuração

```powershell
Copy-Item .env.example .env
Copy-Item hop/environments/dev-secrets.json.example hop/environments/dev-secrets.json
# edite os dois com suas credenciais locais
```

Os schemas `bronze`, `silver`, `qualidade`, `gold`, `auditoria`, `mestre` e `lgpd`
são criados pelo próprio workflow (actions SQL e script de LGPD).
O usuário de leitura do Superset é criado uma vez com `sql/06_criar_usuario_superset.sql`
(a senha é definida manualmente, fora do Git).

## Execução

```powershell
# carga completa (Bronze → Silver → qualidade → Gold), com log em logs/
scripts\executar_carga_completa.bat

# agendamento diário às 06:00 no Agendador de Tarefas do Windows
powershell -ExecutionPolicy Bypass -File scripts\configurar_agendamento.ps1
```

Etapas do workflow `carga_completa.hwf`:

```
schemas e tabelas → Bronze (4) → Silver (4) → dados mestres → proteção LGPD
→ testes de qualidade → Gold (4) → publicação de metadados (OpenMetadata)
```

Estados finais: **sucesso**, **sucesso com ressalvas** (teste de ALERTA reprovado ou
OpenMetadata indisponível; código de saída 0) e **falha** (erro de etapa ou teste
CRÍTICO reprovado; código de saída 1, e a Gold não é publicada). A duração de cada
etapa fica em `auditoria.log_etapas`.

## Parquet e Apache Beam (RF24–RF25)

O processamento distribuído foi implementado **no próprio Apache Hop**, com
os plugins `hop-engines-beam` e `hop-tech-parquet` (instalados pelo Marketplace).
Não há `pipeline.py`: o pipeline `engajamento_beam.hpl` roda sem alteração nas
run configurations `local`, `beam-direct` e `spark-local`.
Medições e comparação: [`beam/evidencias/`](beam/evidencias/).

## Apache Superset (RF16–RF18)

- Superset 6.1.0 via Docker, conectado ao banco com o usuário
  `superset_leitura`, que só lê os schemas `gold` e `qualidade`
  (sem acesso a `bronze`, `silver` e `lgpd`)
  (`sql/06_criar_usuario_superset.sql`; a senha é definida manualmente, fora do Git).
- Consultas do SQL Lab e datasets virtuais: `sql/sql_lab.sql`.
- Dashboard `painel_executivo`: exportação e prints em
  [`superset/exportacao_e_evidencias/`](superset/exportacao_e_evidencias/).

## Dados pessoais (RF32–RF33)

Nenhum dado real: o cadastro de usuários é **fictício**, gerado por
`lgpd/proteger_dados_pessoais.py`. Na Gold, o usuário aparece só por **pseudônimo**
(HMAC), com nome e e-mail **mascarados** e o e-mail guardado como **hash com salt**
no schema restrito `lgpd`. Chave e salt ficam no `.env`. Detalhes em
[`rf32_rf33_lgpd.md`](documentacao/rf32_rf33_lgpd.md).

## Estrutura

```
desafio_dados_2/
├── dados/
│   ├── fontes/        # cópia dos arquivos originais do Desafio 1 (somente leitura)
│   ├── bronze/  silver/  gold/  quarentena/
├── hop/               # projeto Apache Hop (pipelines, workflows, environments)
├── metadata/          # metadados do Hop (ex.: Workflow Log da duração por etapa)
├── beam/              # evidências do Beam (executado pelo Hop)
├── sql/               # schemas, qualidade, Gold, dados mestres, LGPD e SQL Lab
│   └── testes/        # demonstrações: quarentena, conflito de mestres, LGPD, amostras
├── superset/          # exportações e evidências (o Superset roda via Docker)
├── openmetadata/      # evidências de catálogo, glossário e linhagem
├── lgpd/              # script de pseudonimização, hash com salt e mascaramento
├── scripts/           # execução manual e agendamento da carga
└── documentacao/      # arquitetura, regras, mestres, LGPD, narrativa, índice de evidências
```

Versões das ferramentas: [`documentacao/versoes.md`](documentacao/versoes.md).

## Uso da IA.

Durante o desenvolvimento deste projeto, a Inteligência Artificial foi utilizada como uma ferramenta de suporte técnico e analítico, em conformidade com as diretrizes estabelecidas. Na etapa de engenharia e processamento, utilizamos a IA para diagnosticar e explicar mensagens de erro, bem como para obter sugestões de otimização nas transformações construídas no Apache Hop, durante o desenvolvimento ocorreram varios bugs na ferramente Apache hop,
e grande parte desses bugs foram resolvidos com uso da IA. A ferramenta também foi empregada na revisão das consultas SQL, garantindo maior eficiência na extração dos dados. Para assegurar a governança e a segurança das informações, IA foi usada para propor testes de qualidade de dados, estruturar a documentação de metadados e revisar a aplicação das regras de anonimização. Por fim, na etapa analítica, a IA auxiliou na interpretação dos resultados obtidos e no refinamento da comunicação, ajudando a tornar o storytelling mais claro. Ia serviu de apoio a documentação do projeto, os documentos foram gerados com uso de ferramentas como claude e gemini e revisado pelos integrantes do grupo garantindo a conformidade com o projeto.