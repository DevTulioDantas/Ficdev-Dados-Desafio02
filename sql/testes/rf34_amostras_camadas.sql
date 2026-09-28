-- =====================================================================
-- RF34 - Amostras das camadas Bronze, Silver e Gold
-- Volumes por camada + 3 linhas de cada tabela. Nenhum dado do schema lgpd.
-- =====================================================================

\echo '== VOLUMES POR CAMADA =='
SELECT 'bronze' AS camada, 'catalogo_conteudos' AS tabela, count(*) AS linhas FROM bronze.catalogo_conteudos
UNION ALL SELECT 'bronze', 'interacoes_usuarios', count(*) FROM bronze.interacoes_usuarios
UNION ALL SELECT 'bronze', 'comentarios_avaliacoes', count(*) FROM bronze.comentarios_avaliacoes
UNION ALL SELECT 'bronze', 'recomendacao', count(*) FROM bronze.recomendacao
UNION ALL SELECT 'silver', 'catalogo_conteudos', count(*) FROM silver.catalogo_conteudos
UNION ALL SELECT 'silver', 'interacoes_usuarios', count(*) FROM silver.interacoes_usuarios
UNION ALL SELECT 'silver', 'comentarios_avaliacoes', count(*) FROM silver.comentarios_avaliacoes
UNION ALL SELECT 'silver', 'recomendacao', count(*) FROM silver.recomendacao
UNION ALL SELECT 'gold', 'dim_conteudo', count(*) FROM gold.dim_conteudo
UNION ALL SELECT 'gold', 'dim_usuario', count(*) FROM gold.dim_usuario
UNION ALL SELECT 'gold', 'fato_interacoes', count(*) FROM gold.fato_interacoes
UNION ALL SELECT 'gold', 'fato_recomendacao', count(*) FROM gold.fato_recomendacao;

\echo ''
\echo '== BRONZE: dado bruto (texto) + auditoria =='
SELECT * FROM bronze.catalogo_conteudos ORDER BY 1 LIMIT 3;
SELECT * FROM bronze.interacoes_usuarios ORDER BY 1 LIMIT 3;

\echo ''
\echo '== SILVER: tipado, validado, deduplicado =='
SELECT conteudo_id, titulo, tipo, categoria, nivel, carga_horaria_min, data_publicacao
FROM silver.catalogo_conteudos ORDER BY conteudo_id LIMIT 3;
SELECT usuario_id, conteudo_id, tipo_interacao, data_hora, tempo_consumido, percentual_conclusao, avaliacao_atribuida
FROM silver.interacoes_usuarios ORDER BY data_hora LIMIT 3;

\echo ''
\echo '== GOLD: modelo estrela (usuario so por pseudonimo) =='
SELECT conteudo_id, titulo, tipo, categoria, faixa_carga_horaria, ano_publicacao
FROM gold.dim_conteudo ORDER BY conteudo_id LIMIT 3;
SELECT usuario_pseudonimo, faixa_etaria, uf, total_interacoes, usuario_ativo
FROM gold.dim_usuario ORDER BY total_interacoes DESC LIMIT 3;
SELECT usuario_pseudonimo, conteudo_id, tipo_interacao, data_hora, concluiu, antes_da_publicacao
FROM gold.fato_interacoes ORDER BY data_hora LIMIT 3;
SELECT usuario_pseudonimo, posicao, conteudo_id, pontuacao, status, convertida
FROM gold.fato_recomendacao ORDER BY usuario_pseudonimo, posicao LIMIT 3;

\echo ''
\echo '== GOLD: views de KPI =='
SELECT * FROM gold.vw_kpi_engajamento_mensal ORDER BY ano_mes DESC LIMIT 3;
SELECT * FROM gold.vw_kpi_recomendacao;
