# Evidências e critérios de aceite (RF34)

Índice das evidências do Desafio 2, organizado pelos itens do RF34.
Todos os caminhos são relativos à raiz do repositório.

## 1. Exportações dos pipelines e workflows do Apache Hop

| Evidência | Arquivo |
|---|---|
| Workflow de orquestração (Bronze → Silver → mestres → LGPD → qualidade → Gold → metadados) | `hop/workflows/carga_completa.hwf` |
| Bronze: CSV, 2 JSON e PostgreSQL | `hop/pipelines/bronze_catalogo_csv.hpl`, `bronze_interacoes_json.hpl`, `bronze_comentarios_json.hpl`, `bronze_recomendacao_pg.hpl` |
| Silver: validação, padronização, deduplicação e quarentena | `hop/pipelines/silver_catalogo.hpl`, `silver_interacoes.hpl`, `silver_comentarios.hpl`, `silver_recomendacao.hpl` |
| Gold: modelo estrela | `hop/pipelines/gold_dim_conteudo.hpl`, `gold_dim_usuario.hpl`, `gold_fato_interacoes.hpl`, `gold_fato_recomendacao.hpl` |
| Parquet e Beam | `hop/pipelines/exportar_interacoes.hpl`, `ler_csv.hpl`, `ler_parquet.hpl`, `engajamento_beam.hpl`, `comparar_runtimes.hpl` |
| Log de duração por etapa | `hop/pipelines/log_etapas.hpl` + metadado `metadata/workflow-log/log_carga_completa.json` |
| Configuração sem segredos | `hop/environments/dev-config.json`, `hop/environments/dev-secrets.json.example` |
| Execução manual e agendada | `scripts/executar_carga_completa.bat`, `scripts/configurar_agendamento.ps1` |
| Duração, início, término e resultado de cada etapa | `documentacao/evidencias/rf22_duracao_etapas.txt` |
| Publicação de metadados com e sem OpenMetadata no ar | `documentacao/evidencias/rf22_metadados_publicados.txt`, `rf22_metadados_indisponivel.txt` |

## 2. Amostras das camadas Bronze, Silver e Gold

| Evidência | Arquivo |
|---|---|
| Volumes por camada e 3 linhas de cada tabela | `documentacao/evidencias/rf34_amostras_camadas.txt` (script: `sql/testes/rf34_amostras_camadas.sql`) |
| KPIs da Gold | `documentacao/evidencias/rf26_gold_kpis.txt` |
| Regras da Silver | `documentacao/rf21_regras_silver.md` |
| Arquitetura ETL/ELT das camadas | `documentacao/rf19_arquitetura_etl_elt.md` |
| Dados mestres de conteúdo e conflito | `documentacao/rf30_dados_mestres.md`, `documentacao/evidencias/rf30_conflito_conteudo.txt` |

## 3. Registros de quarentena e reprocessamento

| Evidência | Arquivo |
|---|---|
| Falha de regra (registros na quarentena) | `documentacao/evidencias/rf23_falha_regra.txt` |
| Falha de arquivo | `documentacao/evidencias/rf23_falha_arquivo.txt` |
| Falha de conexão | `documentacao/evidencias/rf23_falha_conexao.txt` |
| Correção e reprocessamento da quarentena | `documentacao/evidencias/rf23_reprocessamento.txt` |
| Scripts da demonstração | `sql/testes/rf23_*.sql` |

## 4. Execução do pipeline Apache Beam no runtime

| Evidência | Arquivo |
|---|---|
| Medições CSV x Parquet e local x Beam Direct x Spark | `beam/evidencias/Parquet e Processamento com Apache Beam.md` |
| Resultado idêntico nos três runtimes | `beam/evidencias/comparacao_runtimes.csv` |
| Versões de Beam, Spark e Parquet | `documentacao/versoes.md` |

## 5. Catálogo, glossário, classificações e linhagem no OpenMetadata

| Evidência | Arquivo |
|---|---|
| Governança como código (responsáveis, glossário, classificações LGPD, linhagem) | `openmetadata/governanca.yaml` |
| Publicação dos metadados | `openmetadata/evidencias/publicacao_metadados.txt` |
| Ambiente e ingestão | `openmetadata/README.md`, `openmetadata/docker-compose.yml`, `openmetadata/ingestao/` |
| **Capturas de tela** (catálogo, glossário, classificações, linhagem) | ⚠️ pendente em `openmetadata/evidencias/` |

## 6. Testes de qualidade e controles de LGPD

| Evidência | Arquivo |
|---|---|
| Resultado dos 5 testes, bloqueio em falha crítica | `documentacao/evidencias/rf31_resultados_qualidade.txt` |
| Evolução da qualidade por execução | gráfico `evolucao_qualidade` no painel (`superset/exportacao_e_evidencias/painel_executivo_export.zip`) |
| Inventário, técnicas e comparação | `documentacao/rf32_rf33_lgpd.md` |
| Cadastro fictício x Gold protegida, hash e permissões | `documentacao/evidencias/rf33_lgpd_protecao.txt` |
| Dashboard sem acesso ao schema `lgpd` | `superset/exportacao_e_evidencias/Rf33_sqllab_lgpd_bloqueado.png` |
| Dashboard exibindo só dados protegidos | ⚠️ pendente: `superset/exportacao_e_evidencias/rf33_dashboard_dados_protegidos.png` |
| Implementação | `lgpd/proteger_dados_pessoais.py`, `sql/09_criar_tabelas_lgpd.sql` |

## 7. SQL Lab, dashboard, filtros cruzados e alerta

| Evidência | Arquivo |
|---|---|
| 3 consultas do SQL Lab (datasets virtuais) | `sql/sql_lab.sql` |
| Dashboard exportado (gráficos, datasets, textos, filtros) | `superset/exportacao_e_evidencias/painel_executivo_export.zip` |
| Filtro nativo por categoria | `superset/exportacao_e_evidencias/Rf18_Filtro_categoria.png` |
| Filtro cruzado (barra → KPI) | `superset/exportacao_e_evidencias/Rf18_cross_filter.png` |
| Alerta de qualidade (Q04 > 5%) | `superset/exportacao_e_evidencias/Rf18_alerta.png` |
| Usuário do dashboard restrito a Gold e qualidade | `superset/exportacao_e_evidencias/Rf26_sqllab_bronze_bloqueado.png`, `Rf26_sqllab_gold_permitida.png`, `documentacao/evidencias/rf26_usuario_superset_restrito.txt` |

## 8. Narrativa executiva e recomendação final

| Evidência | Arquivo |
|---|---|
| Contexto, fatos, descoberta, hipóteses e recomendação priorizada | `documentacao/narrativa_executiva.md` |
| Textos interpretativos dentro do painel | `painel_executivo` (no export do Superset) |

## Critérios de aceite: situação

| Critério | Situação |
|---|---|
| Pipeline executa de ponta a ponta, manual e agendado, com 3 estados finais | ✅ |
| Nenhum registro perdido: aprovados + quarentena = extraídos | ✅ |
| Mesmo resultado em três runtimes | ✅ |
| Gold bloqueada por falha crítica de qualidade | ✅ |
| Dashboard sem acesso a dados pessoais nem a Bronze/Silver | ✅ |
| Segredos fora do repositório (`.env`, `dev-secrets.json`) | ✅ |
| Capturas do OpenMetadata | ⚠️ pendente |
