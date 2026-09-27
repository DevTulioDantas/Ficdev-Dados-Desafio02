-- =====================================================================
-- Qualidade de dados (RF31) - execucao dos testes
--
-- Executado pelo workflow carga_completa, depois da camada Silver e
-- antes da camada Gold. Na action SQL do Hop, a opcao de substituicao
-- de variaveis deve estar LIGADA: ${Internal.Workflow.ID} vira o
-- identificador da execucao (o mesmo gravado nas camadas Bronze e Silver).
--
-- Cada teste mede: total de registros, registros com problema e o valor
-- da metrica. O resultado (APROVADO/REPROVADO) vem da comparacao com o
-- limite cadastrado em qualidade.regras_testes.
-- Idempotente: reexecutar na mesma execucao substitui os resultados.
-- =====================================================================

DELETE FROM qualidade.resultados_testes
 WHERE id_execucao = '${Internal.Workflow.ID}';

WITH medidas AS (

  -- Q01 Completude: % de conteudos com descricao preenchida
  SELECT 'Q01' AS teste_id,
         COUNT(*) AS total,
         COUNT(*) FILTER (WHERE descricao IS NULL OR btrim(descricao) = '') AS problema,
         100.0 * COUNT(*) FILTER (WHERE descricao IS NOT NULL AND btrim(descricao) <> '')
               / NULLIF(COUNT(*), 0) AS valor
  FROM silver.catalogo_conteudos

  UNION ALL
  -- Q02 Validade: % de recomendacoes com pontuacao entre 0 e 100
  SELECT 'Q02',
         COUNT(*),
         COUNT(*) FILTER (WHERE pontuacao IS NULL OR pontuacao < 0 OR pontuacao > 100),
         100.0 * COUNT(*) FILTER (WHERE pontuacao BETWEEN 0 AND 100) / NULLIF(COUNT(*), 0)
  FROM silver.recomendacao

  UNION ALL
  -- Q03 Unicidade: quantidade de conteudo_id repetidos
  SELECT 'Q03',
         COUNT(*),
         COUNT(*) - COUNT(DISTINCT conteudo_id),
         COUNT(*) - COUNT(DISTINCT conteudo_id)
  FROM silver.catalogo_conteudos

  UNION ALL
  -- Q04 Consistencia: % de interacoes anteriores a publicacao do conteudo
  SELECT 'Q04',
         COUNT(*),
         COUNT(*) FILTER (WHERE i.data_hora::date < c.data_publicacao),
         100.0 * COUNT(*) FILTER (WHERE i.data_hora::date < c.data_publicacao) / NULLIF(COUNT(*), 0)
  FROM silver.interacoes_usuarios i
  LEFT JOIN silver.catalogo_conteudos c ON c.conteudo_id = i.conteudo_id

  UNION ALL
  -- Q05 Integridade referencial: interacoes com conteudo inexistente
  SELECT 'Q05',
         COUNT(*),
         COUNT(*) FILTER (WHERE c.conteudo_id IS NULL),
         COUNT(*) FILTER (WHERE c.conteudo_id IS NULL)
  FROM silver.interacoes_usuarios i
  LEFT JOIN silver.catalogo_conteudos c ON c.conteudo_id = i.conteudo_id
)
INSERT INTO qualidade.resultados_testes
  (id_execucao, teste_id, fonte, total_registros, registros_com_problema,
   valor_medido, limite, severidade, resultado, data_hora_teste)
SELECT '${Internal.Workflow.ID}',
       r.teste_id,
       r.fonte,
       m.total,
       m.problema,
       round(COALESCE(m.valor, 0), 2),
       r.limite,
       r.severidade,
       CASE
         WHEN r.operador = '>=' AND round(COALESCE(m.valor, 0), 2) >= r.limite THEN 'APROVADO'
         WHEN r.operador = '<=' AND round(COALESCE(m.valor, 0), 2) <= r.limite THEN 'APROVADO'
         WHEN r.operador = '='  AND round(COALESCE(m.valor, 0), 2) =  r.limite THEN 'APROVADO'
         ELSE 'REPROVADO'
       END,
       now()
FROM qualidade.regras_testes r
JOIN medidas m ON m.teste_id = r.teste_id;
