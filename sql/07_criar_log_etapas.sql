-- =====================================================================
-- Log de execucao por etapa do workflow carga_completa (RF22)
--
-- Alimentada pelo pipeline hop/log/log_etapas.hpl, que o Hop executa
-- automaticamente ao fim do workflow (metadado Workflow Log
-- "log_carga_completa"). Uma linha por action executada.
--
-- Idempotente: pode rodar quantas vezes for preciso.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS auditoria;

CREATE TABLE IF NOT EXISTS auditoria.log_etapas (
    id_log              BIGSERIAL PRIMARY KEY,
    workflow            VARCHAR(200),
    id_canal_workflow   VARCHAR(100),     -- log channel do workflow: agrupa as etapas de uma execucao
    inicio_workflow     TIMESTAMP,
    ordem               INTEGER,          -- numero da action no workflow
    etapa               VARCHAR(200),     -- nome da action
    resultado           BOOLEAN,          -- true = sucesso, false = falha
    erros               INTEGER,
    termino             TIMESTAMP,        -- data/hora de log da action (fim)
    duracao_ms          BIGINT,
    data_hora_registro  TIMESTAMP DEFAULT now()
);

COMMENT ON TABLE auditoria.log_etapas IS
    'RF22 - inicio, termino, duracao e resultado de cada etapa do workflow carga_completa';

-- Tabela pronta para leitura: inicio calculado e duracao em segundos
CREATE OR REPLACE VIEW auditoria.vw_duracao_etapas AS
SELECT
    l.inicio_workflow                                           AS execucao,
    l.ordem,
    l.etapa,
    l.termino - make_interval(secs => l.duracao_ms / 1000.0)    AS inicio,
    l.termino,
    ROUND(l.duracao_ms / 1000.0, 2)                             AS duracao_s,
    CASE WHEN l.resultado THEN 'SUCESSO' ELSE 'FALHA' END       AS resultado,
    l.erros
FROM auditoria.log_etapas l
ORDER BY l.inicio_workflow DESC, l.termino;
