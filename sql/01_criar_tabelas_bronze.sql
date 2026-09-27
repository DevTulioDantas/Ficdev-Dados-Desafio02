-- =====================================================================
-- Camada Bronze — tabelas de ingestão (RF20)
-- Idempotente (IF NOT EXISTS): pode rodar quantas vezes for preciso.
--
-- Regras da Bronze:
--  * cópia fiel da fonte, sem transformações destrutivas,
--  * campos vindos de ARQUIVO (CSV/JSON) ficam como TEXT — arquivo não
--    tem tipo, a conversão é responsabilidade da Silver,
--  * campos vindos de BANCO mantêm o tipo original da fonte,
--  * sem chave primária: duplicatas da fonte são preservadas e tratadas
--    na Silver,
--  * 3 campos de auditoria: origem, data_hora_ingestao, id_execucao.
-- =====================================================================

-- Fonte: dados/fontes/catalogo_conteudos.csv  (pipeline bronze_catalogo_csv)
CREATE TABLE IF NOT EXISTS bronze.catalogo_conteudos
(
  conteudo_id        TEXT
, titulo             TEXT
, tipo               TEXT
, categoria          TEXT
, nivel              TEXT
, carga_horaria_min  TEXT
, data_publicacao    TEXT
, descricao          TEXT
, autor              TEXT
, origem             TEXT
, data_hora_ingestao TIMESTAMP
, id_execucao        TEXT
);

-- Fonte: dados/fontes/interacoes_usuarios.json  (pipeline bronze_interacoes_json)
CREATE TABLE IF NOT EXISTS bronze.interacoes_usuarios
(
  usuario_id           TEXT
, conteudo_id          TEXT
, tipo_interacao       TEXT
, data_hora            TEXT
, tempo_consumido      TEXT
, percentual_conclusao TEXT
, avaliacao_atribuida  TEXT
, origem               TEXT
, data_hora_ingestao   TIMESTAMP
, id_execucao          TEXT
);

-- Fonte: dados/fontes/comentarios_avaliacoes.json  (pipeline bronze_comentarios_json)
-- "tags" guarda a lista JSON inteira como texto, ex.: ["etl","spark","iniciante"]
CREATE TABLE IF NOT EXISTS bronze.comentarios_avaliacoes
(
  usuario_id         TEXT
, conteudo_id        TEXT
, avaliacao          TEXT
, comentario         TEXT
, tags               TEXT
, "data"             TEXT
, origem             TEXT
, data_hora_ingestao TIMESTAMP
, id_execucao        TEXT
);

-- Fonte: public.recomendacao do Desafio 1  (pipeline bronze_recomendacao_pg)
-- Tipos idênticos aos da tabela de origem.
CREATE TABLE IF NOT EXISTS bronze.recomendacao
(
  recomendacao_id    BIGINT
, usuario_id         INTEGER
, conteudo_id        INTEGER
, pontuacao          NUMERIC(5,2)
, posicao            INTEGER
, status             VARCHAR(20)
, data_geracao       TIMESTAMP
, origem             TEXT
, data_hora_ingestao TIMESTAMP
, id_execucao        TEXT
);
