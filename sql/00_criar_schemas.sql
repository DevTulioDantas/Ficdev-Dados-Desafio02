-- =====================================================================
-- Prepara os schemas da arquitetura medallion (Aula 03 — Módulo 2).
-- Executado pela action SQL no início do workflow principal:
-- "o workflow prepara o terreno antes de pisar nele".
-- Idempotente: pode rodar quantas vezes for preciso.
-- As tabelas do Desafio 1 continuam no schema "public" e são a FONTE.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS bronze;   -- dado bruto, como veio da fonte (staging)
CREATE SCHEMA IF NOT EXISTS silver;   -- dado limpo, padronizado, deduplicado, tipado
                                      -- + silver.rejeitados (quarentena)
CREATE SCHEMA IF NOT EXISTS gold;     -- dado agregado e modelado para análise

COMMENT ON SCHEMA bronze IS 'Camada Bronze: dado bruto, como veio da fonte';
COMMENT ON SCHEMA silver IS 'Camada Silver: dado limpo, padronizado, deduplicado e tipado';
COMMENT ON SCHEMA gold   IS 'Camada Gold: dado agregado e modelado para análise';
