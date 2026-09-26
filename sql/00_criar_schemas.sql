-- =====================================================================
-- Passo 0 — Schemas das camadas do Desafio 2
-- Roda no MESMO banco do Desafio 1 (desafio_dados). As tabelas do
-- Desafio 1 continuam intactas no schema "public" e passam a ser FONTE.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS bronze;      -- cópia fiel + campos de auditoria
CREATE SCHEMA IF NOT EXISTS silver;      -- dados padronizados e validados
CREATE SCHEMA IF NOT EXISTS gold;        -- tabelas/visões para KPIs e Superset
CREATE SCHEMA IF NOT EXISTS quarentena;  -- registros rejeitados + motivo
CREATE SCHEMA IF NOT EXISTS controle;    -- execuções, etapas, testes de qualidade

COMMENT ON SCHEMA bronze     IS 'Camada Bronze: dados ingeridos sem transformações destrutivas';
COMMENT ON SCHEMA silver     IS 'Camada Silver: dados padronizados, deduplicados e validados';
COMMENT ON SCHEMA gold       IS 'Camada Gold: modelos analíticos consumidos pelo SQL Lab e Superset';
COMMENT ON SCHEMA quarentena IS 'Registros inválidos, com regra violada e mensagem de erro';
COMMENT ON SCHEMA controle   IS 'Metadados operacionais: execuções, duração, status e qualidade';
