-- =====================================================================
-- RF23 - Reprocessamento, etapa 1: CORRIGIR registros da quarentena
--
-- Simula o trabalho do responsavel pelos dados: analisar o motivo do
-- erro e corrigir o registro diretamente em silver.rejeitados_catalogo.
--
--   2001 : CAT04 | CAT06  -> categoria e carga horaria corrigidas
--   2002 : CAT08          -> data inexistente corrigida para 2025-02-28
--   X12  : CAT01 | CAT03  -> NAO corrigido de proposito
--                            (deve voltar para a quarentena)
-- =====================================================================

UPDATE silver.rejeitados_catalogo
   SET categoria         = 'DevOps & Cloud',
       carga_horaria_min = '60'
 WHERE conteudo_id = '2001';

UPDATE silver.rejeitados_catalogo
   SET data_publicacao = '2025-02-28'
 WHERE conteudo_id = '2002';

-- Conferencia: como ficaram os registros apos a correcao
SELECT conteudo_id, tipo, categoria, carga_horaria_min, data_publicacao, codigo_erro
FROM silver.rejeitados_catalogo
ORDER BY conteudo_id;
