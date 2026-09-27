-- =====================================================================
-- RF23 — Teste da quarentena do pipeline silver_catalogo
--
-- Injeta 4 registros problemáticos em bronze.catalogo_conteudos,
-- cada um exercitando uma proteção diferente da Silver.
-- Os arquivos de dados/fontes NÃO são alterados.
--
-- Para desfazer: reexecutar o pipeline bronze_catalogo_csv
-- (truncate + recarga a partir do CSV original).
--
-- Os demais campos são copiados do conteúdo 1 (válido), para que cada
-- registro viole apenas as regras que se quer testar.
-- =====================================================================

INSERT INTO bronze.catalogo_conteudos
  (conteudo_id, titulo, tipo, categoria, nivel, carga_horaria_min,
   data_publicacao, descricao, autor, origem, data_hora_ingestao, id_execucao)

-- T1: ID não numérico + tipo fora da lista  → CAT01 | CAT03 (Data Validator)
SELECT 'X12', 'TESTE RF23 - id e tipo invalidos', 'Livro', categoria, nivel,
       carga_horaria_min, data_publicacao, descricao, autor,
       'teste_rf23', now(), 'teste_rf23'
FROM bronze.catalogo_conteudos WHERE conteudo_id = '1'

UNION ALL
-- T2: categoria fora da lista + carga zero  → CAT04 | CAT06 (Data Validator)
SELECT '2001', 'TESTE RF23 - categoria e carga invalidas', tipo, 'Marketing', nivel,
       '0', data_publicacao, descricao, autor,
       'teste_rf23', now(), 'teste_rf23'
FROM bronze.catalogo_conteudos WHERE conteudo_id = '1'

UNION ALL
-- T3: data com formato válido, mas impossível (30/02)
--     passa no regex da CAT07 e é barrada na conversão (Converter tipos)
SELECT '2002', 'TESTE RF23 - data impossivel', tipo, categoria, nivel,
       carga_horaria_min, '2025-02-30', descricao, autor,
       'teste_rf23', now(), 'teste_rf23'
FROM bronze.catalogo_conteudos WHERE conteudo_id = '1'

UNION ALL
-- T4: registro válido com conteudo_id repetido (duplica o id 1)
--     não é erro de regra: é descartado pelo Deduplicar
SELECT '1', titulo, tipo, categoria, nivel,
       carga_horaria_min, data_publicacao, descricao, autor,
       'teste_rf23', now(), 'teste_rf23'
FROM bronze.catalogo_conteudos WHERE conteudo_id = '1';

-- Conferência: deve listar 4 linhas de teste
SELECT conteudo_id, titulo, tipo, categoria, carga_horaria_min, data_publicacao
FROM bronze.catalogo_conteudos
WHERE origem = 'teste_rf23';
