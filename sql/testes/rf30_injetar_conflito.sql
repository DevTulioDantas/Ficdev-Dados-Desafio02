-- =====================================================================
-- RF30 - Demonstracao de dois registros conflitantes do mesmo conteudo
--
-- Simula o mesmo curso cadastrado duas vezes no catalogo, com divergencias:
--   9001: cadastro antigo, titulo em CAIXA ALTA, autor com "Profa.",
--         600 min, publicado em 2025-03-10, COM descricao
--   9002: versao revisada, titulo bem escrito, autor sem titulo,
--         720 min, publicado em 2026-02-15, SEM descricao
--   (mesmo tipo e mesmo nivel: pela chave de negocio, e o mesmo conteudo)
--
-- Depois de injetar, rode sql/08_dados_mestres_conteudo.sql e
-- sql/testes/rf30_conferir_conflito.sql. Para desfazer: rf30_limpar_conflito.sql
-- (a proxima carga completa tambem recria a Silver sem estes registros).
-- =====================================================================

DELETE FROM silver.catalogo_conteudos WHERE conteudo_id IN (9001, 9002);

INSERT INTO silver.catalogo_conteudos
    (conteudo_id, titulo, tipo, categoria, nivel, carga_horaria_min,
     data_publicacao, descricao, autor, data_hora_processamento, id_execucao)
VALUES
    (9001, 'FUNDAMENTOS DE GOVERNANÇA DE DADOS COM LGPD', 'Curso', 'Segurança & Governança',
     'Intermediário', 600, DATE '2025-03-10',
     'Curso introdutório sobre governança de dados e adequação à LGPD.',
     'Profa. Marina Alves Costa', now(), 'teste_rf30'),
    (9002, 'Fundamentos de Governança de Dados com LGPD', 'Curso', 'Segurança & Governança',
     'Intermediário', 720, DATE '2026-02-15',
     NULL,
     'Marina Alves Costa', now(), 'teste_rf30');
