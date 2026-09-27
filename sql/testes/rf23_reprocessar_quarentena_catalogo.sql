-- =====================================================================
-- RF23 - Reprocessamento, etapa 2: DEVOLVER a quarentena para a Bronze
--
-- Todos os registros da quarentena (corrigidos ou nao) voltam para a
-- Bronze com origem = 'reprocessamento_quarentena'. Em seguida, o
-- pipeline silver_catalogo deve ser executado: ele valida tudo de novo,
--   * registros corrigidos  -> entram na Silver
--   * registros com erro    -> voltam para a quarentena
-- A mesma regra de validacao vale para a carga normal e para o
-- reprocessamento (nenhum atalho que pule as regras da Silver).
--
-- Limitacao: a proxima carga completa recarrega a Bronze a partir do
-- arquivo de origem. A correcao definitiva deve ser feita na fonte.
-- =====================================================================

INSERT INTO bronze.catalogo_conteudos
  (conteudo_id, titulo, tipo, categoria, nivel, carga_horaria_min,
   data_publicacao, descricao, autor, origem, data_hora_ingestao, id_execucao)
SELECT conteudo_id, titulo, tipo, categoria, nivel, carga_horaria_min,
       data_publicacao, descricao, autor,
       'reprocessamento_quarentena', now(), id_execucao
FROM silver.rejeitados_catalogo;

-- Conferencia: registros devolvidos para a Bronze
SELECT origem, COUNT(*) AS registros
FROM bronze.catalogo_conteudos
GROUP BY origem
ORDER BY origem;
