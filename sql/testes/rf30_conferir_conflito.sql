-- RF30 - Resultado da consolidacao dos dois registros conflitantes (9001 e 9002)

\echo '== 1) Registros de origem e a ordem de sobrevivencia =='
SELECT conteudo_id, id_mestre, posicao, completude, titulo, nivel,
       carga_horaria_min, data_publicacao, autor,
       CASE WHEN descricao IS NULL THEN '(vazia)' ELSE 'preenchida' END AS descricao
FROM mestre.vw_conteudo_sobrevivencia
WHERE conteudo_id IN (9001, 9002)
ORDER BY posicao;

\echo '== 2) Tabela de correspondencia (de/para) =='
SELECT conteudo_id, id_mestre, vencedor, motivo, chave_negocio
FROM mestre.conteudo_correspondencia
WHERE conteudo_id IN (9001, 9002)
ORDER BY conteudo_id;

\echo '== 3) Registro mestre (golden record) =='
SELECT id_mestre, titulo, nivel, carga_horaria_min, autor,
       left(descricao, 40) AS descricao, data_primeira_publicacao, data_ultima_versao,
       conteudo_id_vencedor, qtd_registros_origem
FROM mestre.conteudo
WHERE id_mestre = 'MC-009001';

\echo '== 4) Visao geral: conteudos de origem x registros mestres =='
SELECT (SELECT count(*) FROM mestre.conteudo_correspondencia)                    AS registros_origem,
       (SELECT count(*) FROM mestre.conteudo)                                     AS registros_mestres,
       (SELECT count(*) FROM mestre.conteudo WHERE qtd_registros_origem > 1)      AS mestres_consolidados;
