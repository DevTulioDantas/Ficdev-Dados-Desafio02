-- =====================================================================
-- SQL Lab (RF17) - consultas do Apache Superset
--
-- Todas as consultas leem SOMENTE a camada Gold e o schema qualidade
-- (usuario de banco superset_leitura - ver sql/06_criar_usuario_superset.sql).
-- Os resultados sao reproduziveis: basta rodar a carga completa e
-- executar a consulta no SQL Lab com o banco desafio_dados_gold.
--
-- Consulta 1 -> dataset virtual  vds_engajamento_categoria
-- Consulta 2 -> dataset virtual  vds_conversao_recomendacao
-- Consulta 3 -> dataset virtual  vds_qualidade_evolucao
--
-- Recursos de SQL exigidos pelo RF17:
--   juncao                 : JOIN fato x dimensao (consultas 1 e 2) e regras x resultados (3)
--   agregacao              : COUNT, SUM, AVG com GROUP BY (1, 2 e 3)
--   expressao condicional  : CASE WHEN / FILTER (1, 2 e 3)
--   funcao de data         : date_trunc e conversao ::date (1, 2 e 3)
-- =====================================================================


-- ---------------------------------------------------------------------
-- Consulta 1 - vds_engajamento_categoria
-- Finalidade: engajamento e taxa de conclusao por mes, categoria e tipo
-- de conteudo. Base dos KPIs "usuarios ativos" e "taxa de conclusao" e
-- dos filtros de periodo e de categoria do dashboard.
--
-- Campos calculados:
--   mes                     date_trunc('month', data_hora)::date - 1o dia do mes (eixo de tempo)
--   interacoes              COUNT(*)
--   usuarios_ativos         COUNT(DISTINCT usuario_id) no grupo
--   pares_usuario_conteudo  pares (usuario, conteudo) distintos com alguma interacao
--   pares_concluidos        pares (usuario, conteudo) com interacao do tipo conclusao
--   taxa_conclusao_pct      100 * pares_concluidos / pares_usuario_conteudo
--                           (mesma regra da view gold.vw_kpi_engajamento_mensal)
--   avaliacao_media         AVG(avaliacao_atribuida) - so interacoes com nota
--   tempo_consumido_total   SUM(tempo_consumido)
--   interacoes_inconsistentes  interacoes antes da publicacao do conteudo (regra Q04)
--   nivel_engajamento       CASE: Alto (>= 8 interacoes no grupo), Medio (>= 4), Baixo (< 4)
-- ---------------------------------------------------------------------
SELECT
    date_trunc('month', f.data_hora)::date                        AS mes,
    d.categoria,
    d.tipo                                                        AS tipo_conteudo,
    COUNT(*)                                                      AS interacoes,
    COUNT(DISTINCT f.usuario_id)                                  AS usuarios_ativos,
    COUNT(DISTINCT (f.usuario_id, f.conteudo_id))                 AS pares_usuario_conteudo,
    COUNT(DISTINCT (f.usuario_id, f.conteudo_id)) FILTER (WHERE f.concluiu) AS pares_concluidos,
    ROUND(100.0 * COUNT(DISTINCT (f.usuario_id, f.conteudo_id)) FILTER (WHERE f.concluiu)
          / NULLIF(COUNT(DISTINCT (f.usuario_id, f.conteudo_id)), 0), 2)       AS taxa_conclusao_pct,
    ROUND(AVG(f.avaliacao_atribuida), 2)                          AS avaliacao_media,
    SUM(f.tempo_consumido)                                        AS tempo_consumido_total,
    COUNT(*) FILTER (WHERE f.antes_da_publicacao)                 AS interacoes_inconsistentes,
    CASE
        WHEN COUNT(*) >= 8 THEN 'Alto'
        WHEN COUNT(*) >= 4 THEN 'Medio'
        ELSE 'Baixo'
    END                                                           AS nivel_engajamento
FROM gold.fato_interacoes f
JOIN gold.dim_conteudo d ON d.conteudo_id = f.conteudo_id
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;


-- ---------------------------------------------------------------------
-- Consulta 2 - vds_conversao_recomendacao
-- Finalidade: desempenho das recomendacoes do LOTE MAIS RECENTE por
-- status, faixa de pontuacao e categoria do conteudo recomendado.
-- Base do KPI "conversao de recomendacao".
--
-- Campos calculados:
--   data_geracao        data_geracao::date - dia em que o lote foi gerado
--   faixa_pontuacao     CASE: Alta (>= 70), Media (>= 40), Baixa (< 40)
--   recomendacoes       COUNT(*)
--   usuarios            COUNT(DISTINCT usuario_id)
--   pontuacao_media     AVG(pontuacao)
--   convertidas         recomendacoes seguidas de interacao do usuario no conteudo recomendado
--   taxa_conversao_pct  100 * convertidas / recomendacoes
-- ---------------------------------------------------------------------
SELECT
    r.data_geracao::date                                          AS data_geracao,
    r.status,
    CASE
        WHEN r.pontuacao >= 70 THEN 'Alta'
        WHEN r.pontuacao >= 40 THEN 'Media'
        ELSE 'Baixa'
    END                                                           AS faixa_pontuacao,
    d.categoria                                                   AS categoria_recomendada,
    COUNT(*)                                                      AS recomendacoes,
    COUNT(DISTINCT r.usuario_id)                                  AS usuarios,
    ROUND(AVG(r.pontuacao), 2)                                    AS pontuacao_media,
    COUNT(*) FILTER (WHERE r.convertida)                          AS convertidas,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.convertida) / NULLIF(COUNT(*), 0), 2) AS taxa_conversao_pct
FROM gold.fato_recomendacao r
JOIN gold.dim_conteudo d ON d.conteudo_id = r.conteudo_id
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4;


-- ---------------------------------------------------------------------
-- Consulta 3 - vds_qualidade_evolucao
-- Finalidade: evolucao das metricas de qualidade por execucao da carga
-- (grafico de evolucao do RF31 e condicao do alerta do RF18).
--
-- Campos calculados:
--   data_execucao       data_hora_teste::date
--   momento_execucao    date_trunc('second', data_hora_teste) - uma execucao por ponto no grafico
--   teste               teste_id || ' - ' || dimensao
--   situacao            CASE: OK / ALERTA / BLOQUEIO (critico reprovado)
--   distancia_limite    valor_medido - limite (quanto falta ou sobra ate o limite)
-- ---------------------------------------------------------------------
SELECT
    t.data_hora_teste::date                                       AS data_execucao,
    date_trunc('second', t.data_hora_teste)                       AS momento_execucao,
    t.id_execucao,
    t.teste_id,
    t.teste_id || ' - ' || r.dimensao                             AS teste,
    r.descricao,
    t.fonte,
    t.valor_medido,
    t.limite,
    r.operador,
    r.unidade,
    t.severidade,
    t.resultado,
    CASE
        WHEN t.resultado = 'APROVADO'  THEN 'OK'
        WHEN t.severidade = 'CRITICA'  THEN 'BLOQUEIO'
        ELSE 'ALERTA'
    END                                                           AS situacao,
    t.valor_medido - t.limite                                     AS distancia_limite,
    t.total_registros,
    t.registros_com_problema
FROM qualidade.resultados_testes t
JOIN qualidade.regras_testes r ON r.teste_id = t.teste_id
ORDER BY t.data_hora_teste, t.teste_id;
