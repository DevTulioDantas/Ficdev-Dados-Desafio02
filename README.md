# Desafio Prático 2 — Pipeline Governado, Escalável e Seguro de Conteúdos Educacionais

Fundamentos de Dados para IA — FIC_DEV

Continuação do [Desafio Prático 1](https://github.com/DevTulioDantas/-Ficdev-Dados-Desafio01).

## Equipe

| Integrante | Responsabilidade principal |
|---|---|
| Túlio Dantas | _a definir_ |
| Gabriele Silva | _a definir_ |
| Libia Canete | _a definir_ |

## Status

| Requisito | Descrição | Status |
|---|---|---|
| RF15 | Continuidade e configuração | 🟡 em andamento |
| RF16–RF18 | Storytelling, SQL Lab, filtros e alertas | ⚪ |
| RF19 | Arquitetura ETL/ELT | ⚪ |
| RF20–RF23 | Hop: Bronze, Silver, workflow, quarentena | ⚪ |
| RF24–RF25 | Parquet e Apache Beam | ⚪ |
| RF26 | Camada Gold | ⚪ |
| RF27–RF29 | OpenMetadata: catálogo, glossário, linhagem | ⚪ |
| RF30–RF31 | Dados mestres e qualidade | ⚪ |
| RF32–RF33 | LGPD | ⚪ |

## Configuração (RF15)

Parâmetros ficam **fora** dos pipelines; segredos ficam **fora** do repositório.

| Arquivo | O que guarda | Versionado? |
|---|---|---|
| `config.json` | caminhos, schemas, nomes (scripts Python) | ✅ sim |
| `hop/environments/dev-config.json` | variáveis do ambiente Hop `dev` | ✅ sim |
| `hop/environments/dev-secrets.json` | usuário/senha do banco para o Hop | ❌ não (modelo: `.example`) |
| `.env` | senhas, salt e chave da LGPD para o Python | ❌ não (modelo: `.env.example`) |

### Primeira configuração

```powershell
Copy-Item .env.example .env
Copy-Item hop/environments/dev-secrets.json.example hop/environments/dev-secrets.json
# edite os dois com suas credenciais locais
```

Os schemas `bronze`, `silver` e `gold` são criados automaticamente pela
primeira action (SQL) do workflow principal, a partir de `sql/00_criar_schemas.sql`.

## Estrutura

```
desafio_dados_2/
├── dados/
│   ├── fontes/        # cópia dos arquivos originais do Desafio 1 (somente leitura)
│   ├── bronze/  silver/  gold/  quarentena/
├── hop/               # projeto Apache Hop (pipelines, workflows, environments)
├── beam/              # pipeline Apache Beam + evidências
├── sql/               # schemas, camada Gold e consultas do SQL Lab
├── superset/          # exportações e evidências (o Superset roda via Docker)
├── openmetadata/      # evidências de catálogo, glossário e linhagem
├── qualidade/         # regras e resultados dos testes
├── lgpd/              # inventário de dados e técnicas de proteção
└── documentacao/      # arquitetura, linhagem, storytelling, versões
```

Versões das ferramentas: [`documentacao/versoes.md`](documentacao/versoes.md).
