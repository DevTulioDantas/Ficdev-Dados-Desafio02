-- =====================================================================
-- Migracao UNICA da Gold para o pseudonimo (RF33)
--
-- As tabelas Gold de usuario tinham a coluna usuario_id. O 05 usa
-- CREATE TABLE IF NOT EXISTS e nao altera tabelas existentes, entao e
-- preciso remove-las uma vez; a proxima carga completa recria tudo
-- (tabelas e views de KPI) ja com usuario_pseudonimo.
-- Rodar uma unica vez, com o workflow parado.
-- =====================================================================
DROP TABLE IF EXISTS gold.fato_interacoes, gold.fato_recomendacao, gold.dim_usuario CASCADE;
