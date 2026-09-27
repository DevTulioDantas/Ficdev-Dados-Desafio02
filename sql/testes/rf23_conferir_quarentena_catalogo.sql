-- =====================================================================
-- RF23 — Conferência do teste de quarentena do silver_catalogo
-- Executar depois de: injetar erros → rodar silver_catalogo
-- =====================================================================

-- 1) O que foi para a quarentena, e por quê
SELECT conteudo_id, qtd_erros, codigo_erro, campo_erro, motivo_erro,
       pipeline_origem, data_hora_rejeicao, id_execucao
FROM silver.rejeitados_catalogo
ORDER BY conteudo_id;

-- 2) A Silver continua íntegra: 1000 conteúdos, nenhum registro de teste
SELECT COUNT(*) AS total_silver,
       COUNT(*) FILTER (WHERE titulo LIKE 'TESTE RF23%') AS registros_de_teste
FROM silver.catalogo_conteudos;

-- 3) A equação da Aula 01 fecha:
--    lidos da Bronze = aprovados na Silver + rejeitados + duplicatas descartadas
SELECT
  (SELECT COUNT(*) FROM bronze.catalogo_conteudos)  AS lidos_bronze,
  (SELECT COUNT(*) FROM silver.catalogo_conteudos)  AS aprovados_silver,
  (SELECT COUNT(*) FROM silver.rejeitados_catalogo) AS rejeitados,
  (SELECT COUNT(*) FROM bronze.catalogo_conteudos)
    - (SELECT COUNT(*) FROM silver.catalogo_conteudos)
    - (SELECT COUNT(*) FROM silver.rejeitados_catalogo) AS duplicatas_descartadas;
