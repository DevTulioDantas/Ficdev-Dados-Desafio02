-- =====================================================================
-- Camada Gold (RF26) - tabelas para consumo analitico e views de KPI
-- Idempotente: pode rodar quantas vezes for preciso.
--
-- Modelo estrela:
--   gold.dim_conteudo       1 linha por conteudo
--   gold.dim_usuario        1 linha por usuario (sem dados pessoais)
--   gold.fato_interacoes    1 linha por interacao
--   gold.fato_recomendacao  1 linha por recomendacao do LOTE MAIS RECENTE
--
-- Views de KPI (consumidas pelo SQL Lab e pelo Superset):
--   gold.vw_kpi_engajamento_mensal
--   gold.vw_kpi_conteudo
--   gold.vw_kpi_recomendacao
--
-- A Gold le somente a Silver (e public.usuario, fonte mestre de usuarios).
-- O dashboard le somente a Gold, nunca a Bronze.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Dimensao conteudo
-- Chave: conteudo_id. Descricao e autor ficam fora (texto longo e nome
-- de pessoa: nao sao necessarios aos KPIs - minimizacao de dados).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.dim_conteudo
(
  conteudo_id             INTEGER PRIMARY KEY
, titulo                  TEXT
, tipo                    TEXT
, categoria               TEXT
, nivel                   TEXT
, carga_horaria_min       INTEGER
, faixa_carga_horaria     TEXT
, data_publicacao         DATE
, ano_publicacao          SMALLINT
, data_hora_processamento TIMESTAMP
, id_execucao             TEXT
);

-- ---------------------------------------------------------------------
-- Dimensao usuario
-- Chave: usuario_id. Somente atributos derivados do comportamento.
-- usuario_ativo: interagiu nos 30 dias anteriores a data de referencia
-- (data da interacao mais recente registrada na base).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.dim_usuario
(
  usuario_id              INTEGER PRIMARY KEY
, data_primeira_interacao DATE
, data_ultima_interacao   DATE
, total_interacoes        INTEGER
, conteudos_distintos     INTEGER
, usuario_ativo           BOOLEAN
, data_hora_processamento TIMESTAMP
, id_execucao             TEXT
);

-- ---------------------------------------------------------------------
-- Fato interacoes
-- Grao: 1 interacao (usuario, conteudo, tipo, data_hora).
-- concluiu            : tipo_interacao = conclusao
-- antes_da_publicacao : inconsistencia temporal (teste Q04), mantida e
--                       sinalizada para que o analista possa filtrar
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.fato_interacoes
(
  usuario_id              INTEGER   NOT NULL
, conteudo_id             INTEGER   NOT NULL
, tipo_interacao          TEXT      NOT NULL
, data_hora               TIMESTAMP NOT NULL
, data_interacao          DATE
, ano_mes                 TEXT
, tempo_consumido         INTEGER
, percentual_conclusao    NUMERIC(5,2)
, avaliacao_atribuida     SMALLINT
, concluiu                BOOLEAN
, antes_da_publicacao     BOOLEAN
, data_hora_processamento TIMESTAMP
, id_execucao             TEXT
, PRIMARY KEY (usuario_id, conteudo_id, tipo_interacao, data_hora)
);

-- ---------------------------------------------------------------------
-- Fato recomendacao
-- Grao: 1 recomendacao do lote mais recente (usuario, posicao).
-- Regra de sobrevivencia: a fonte guarda varios lotes de geracao, a Gold
-- publica somente o de maior data_geracao.
-- convertida: o usuario interagiu com o conteudo recomendado DEPOIS da
-- data de geracao da recomendacao.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gold.fato_recomendacao
(
  usuario_id                  INTEGER   NOT NULL
, posicao                     SMALLINT  NOT NULL
, conteudo_id                 INTEGER   NOT NULL
, recomendacao_id             BIGINT
, pontuacao                   NUMERIC(5,2)
, status                      TEXT
, data_geracao                TIMESTAMP NOT NULL
, convertida                  BOOLEAN
, data_primeira_interacao_pos TIMESTAMP
, data_hora_processamento     TIMESTAMP
, id_execucao                 TEXT
, PRIMARY KEY (usuario_id, posicao)
);

-- ---------------------------------------------------------------------
-- KPI: engajamento por mes
-- usuarios_ativos    : usuarios distintos com ao menos 1 interacao no mes
-- taxa_conclusao_pct : 100 * pares (usuario, conteudo) com conclusao
--                      / pares (usuario, conteudo) com alguma interacao
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_kpi_engajamento_mensal AS
SELECT f.ano_mes
     , COUNT(*)                                        AS interacoes
     , COUNT(DISTINCT f.usuario_id)                    AS usuarios_ativos
     , COUNT(DISTINCT (f.usuario_id, f.conteudo_id))   AS pares_usuario_conteudo
     , COUNT(DISTINCT (f.usuario_id, f.conteudo_id)) FILTER (WHERE f.concluiu) AS pares_concluidos
     , ROUND(100.0 * COUNT(DISTINCT (f.usuario_id, f.conteudo_id)) FILTER (WHERE f.concluiu)
             / NULLIF(COUNT(DISTINCT (f.usuario_id, f.conteudo_id)), 0), 2) AS taxa_conclusao_pct
     , ROUND(AVG(f.avaliacao_atribuida), 2)            AS avaliacao_media
     , SUM(f.tempo_consumido)                          AS tempo_consumido_total
FROM gold.fato_interacoes f
GROUP BY f.ano_mes;

-- ---------------------------------------------------------------------
-- KPI: desempenho por categoria e tipo de conteudo
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_kpi_conteudo AS
SELECT d.categoria
     , d.tipo
     , COUNT(*)                                        AS interacoes
     , COUNT(DISTINCT f.usuario_id)                    AS usuarios
     , COUNT(DISTINCT f.conteudo_id)                   AS conteudos_com_interacao
     , ROUND(100.0 * COUNT(DISTINCT (f.usuario_id, f.conteudo_id)) FILTER (WHERE f.concluiu)
             / NULLIF(COUNT(DISTINCT (f.usuario_id, f.conteudo_id)), 0), 2) AS taxa_conclusao_pct
     , ROUND(AVG(f.avaliacao_atribuida), 2)            AS avaliacao_media
     , ROUND(AVG(f.tempo_consumido), 1)                AS tempo_medio_consumido
FROM gold.fato_interacoes f
JOIN gold.dim_conteudo d ON d.conteudo_id = f.conteudo_id
GROUP BY d.categoria, d.tipo;

-- ---------------------------------------------------------------------
-- KPI: recomendacoes do lote mais recente, por status
-- taxa_conversao_pct : 100 * recomendacoes convertidas / recomendacoes
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_kpi_recomendacao AS
SELECT r.data_geracao
     , r.status
     , COUNT(*)                                        AS recomendacoes
     , COUNT(DISTINCT r.usuario_id)                    AS usuarios
     , ROUND(AVG(r.pontuacao), 2)                      AS pontuacao_media
     , COUNT(*) FILTER (WHERE r.convertida)            AS convertidas
     , ROUND(100.0 * COUNT(*) FILTER (WHERE r.convertida) / NULLIF(COUNT(*), 0), 2) AS taxa_conversao_pct
FROM gold.fato_recomendacao r
GROUP BY r.data_geracao, r.status;
