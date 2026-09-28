-- =====================================================================
-- Usuario de banco do Apache Superset (RF26 e RF16-18)
--
-- O Superset e o SQL Lab conectam no PostgreSQL com este usuario, que
-- so tem permissao de LEITURA nos schemas gold e qualidade.
-- Bronze, Silver e o schema public (Desafio 1) ficam inacessiveis:
-- o dashboard nao consegue consultar a Bronze nem por engano.
--
-- A SENHA NAO fica neste arquivo (versionado). Depois de rodar o script,
-- defina a senha manualmente, uma unica vez:
--   ALTER ROLE superset_leitura PASSWORD 'sua_senha'
--
-- Idempotente: pode rodar quantas vezes for preciso.
-- =====================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'superset_leitura') THEN
    CREATE ROLE superset_leitura LOGIN;
  END IF;
END
$$;

COMMENT ON ROLE superset_leitura IS 'Leitura para o Apache Superset: somente schemas gold e qualidade';

GRANT CONNECT ON DATABASE desafio_dados TO superset_leitura;

-- Camada de consumo
GRANT USAGE ON SCHEMA gold TO superset_leitura;
GRANT SELECT ON ALL TABLES IN SCHEMA gold TO superset_leitura;
ALTER DEFAULT PRIVILEGES IN SCHEMA gold GRANT SELECT ON TABLES TO superset_leitura;

-- Resultados dos testes de qualidade (grafico de evolucao do RF31)
GRANT USAGE ON SCHEMA qualidade TO superset_leitura;
GRANT SELECT ON ALL TABLES IN SCHEMA qualidade TO superset_leitura;
ALTER DEFAULT PRIVILEGES IN SCHEMA qualidade GRANT SELECT ON TABLES TO superset_leitura;