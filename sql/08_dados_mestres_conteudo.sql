-- =====================================================================
-- Dados mestres de CONTEUDO (RF30)
--
-- Entidade mestre ....: conteudo
-- Fonte de referencia : silver.catalogo_conteudos (catalogo oficial, CSV do Desafio 1)
-- Chave de negocio ...: titulo normalizado + tipo + nivel + autor normalizado
--                       * titulo sozinho NAO basta: 189 titulos repetidos no catalogo
--                         pertencem a autores diferentes = conteudos distintos;
--                       * nivel entra na chave: o mesmo curso do mesmo autor em nivel
--                         Basico e Avancado e outro produto (carga horaria muito diferente)
-- Atributos essenciais: titulo, tipo, categoria, nivel, carga_horaria_min,
--                       data_publicacao, autor, descricao
--
-- Correspondencia ....: registros com a MESMA chave de negocio sao o mesmo conteudo
-- Sobrevivencia ......: registro vencedor = versao mais recente (data_publicacao),
--                       desempate pelo mais completo e depois pelo menor conteudo_id;
--                       atributos nulos do vencedor sao preenchidos pelos demais;
--                       data de 1a publicacao = a mais antiga do grupo
-- Identificador mestre: MC-<menor conteudo_id do grupo> (estavel entre execucoes)
--
-- Padrao ELT (SQL no PostgreSQL). Idempotente: recalcula tudo a cada execucao.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS mestre;

-- Normalizacao usada na correspondencia: minusculas, sem acentos,
-- sem pontuacao e com espacos unicos
CREATE OR REPLACE FUNCTION mestre.normalizar(txt text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT btrim(regexp_replace(lower(translate(coalesce(txt, ''),
         'ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇçÑñ',
         'AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn')),
         '[^a-z0-9]+', ' ', 'g'))
$$;

-- Autor sem titulo academico/profissional (Prof., Profa., Dr., Dra., Eng.)
CREATE OR REPLACE FUNCTION mestre.normalizar_autor(txt text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT regexp_replace(mestre.normalizar(txt), '^(prof|profa|dr|dra|eng|me|msc) ', '')
$$;

CREATE TABLE IF NOT EXISTS mestre.conteudo (
    id_mestre                 VARCHAR(20) PRIMARY KEY,
    chave_negocio             TEXT NOT NULL UNIQUE,
    titulo                    TEXT,
    tipo                      TEXT,
    categoria                 TEXT,
    nivel                     TEXT,
    carga_horaria_min         INTEGER,
    autor                     TEXT,
    descricao                 TEXT,
    data_primeira_publicacao  DATE,
    data_ultima_versao        DATE,
    conteudo_id_vencedor      INTEGER,
    qtd_registros_origem      INTEGER,
    data_hora_processamento   TIMESTAMP DEFAULT now()
);
COMMENT ON TABLE mestre.conteudo IS 'RF30 - registro mestre (golden record) de conteudo';

CREATE TABLE IF NOT EXISTS mestre.conteudo_correspondencia (
    conteudo_id              INTEGER PRIMARY KEY,
    id_mestre                VARCHAR(20) NOT NULL,
    chave_negocio            TEXT NOT NULL,
    vencedor                 BOOLEAN NOT NULL,
    motivo                   TEXT,
    data_hora_processamento  TIMESTAMP DEFAULT now()
);
COMMENT ON TABLE mestre.conteudo_correspondencia IS 'RF30 - de/para conteudo_id da fonte -> id_mestre';

TRUNCATE mestre.conteudo, mestre.conteudo_correspondencia;

-- 1) Chave de negocio e ordem de sobrevivencia dentro de cada grupo
--    (view: fica disponivel para auditoria e para a demonstracao do conflito)
CREATE OR REPLACE VIEW mestre.vw_conteudo_sobrevivencia AS
WITH base AS (
  SELECT c.conteudo_id, c.titulo, c.tipo, c.categoria, c.nivel, c.carga_horaria_min,
         c.data_publicacao, c.autor, c.descricao,
         mestre.normalizar(c.titulo) || '|' || mestre.normalizar(c.tipo) || '|' ||
         mestre.normalizar(c.nivel) || '|' || mestre.normalizar_autor(c.autor)                                     AS chave_negocio,
         ( (c.titulo IS NOT NULL)::int + (c.tipo IS NOT NULL)::int + (c.categoria IS NOT NULL)::int
         + (c.nivel IS NOT NULL)::int + (c.carga_horaria_min IS NOT NULL)::int
         + (c.data_publicacao IS NOT NULL)::int + (c.autor IS NOT NULL)::int
         + (c.descricao IS NOT NULL)::int )                                   AS completude
  FROM silver.catalogo_conteudos c
)
SELECT b.*,
       row_number() OVER (PARTITION BY chave_negocio
                          ORDER BY data_publicacao DESC NULLS LAST, completude DESC, conteudo_id) AS posicao,
       'MC-' || lpad(min(conteudo_id) OVER (PARTITION BY chave_negocio)::text, 6, '0')           AS id_mestre,
       count(*) OVER (PARTITION BY chave_negocio)                                                 AS qtd
FROM base b;

-- 2) Tabela de correspondencia (todo conteudo_id aponta para um id_mestre)
INSERT INTO mestre.conteudo_correspondencia (conteudo_id, id_mestre, chave_negocio, vencedor, motivo)
SELECT conteudo_id, id_mestre, chave_negocio, posicao = 1,
       CASE
         WHEN qtd = 1      THEN 'registro unico'
         WHEN posicao = 1  THEN 'vencedor: versao mais recente (desempate: completude, menor id)'
         ELSE                   'duplicado: consolidado no registro mestre'
       END
FROM mestre.vw_conteudo_sobrevivencia;

-- 3) Registro mestre: atributos do vencedor; nulos preenchidos pelos demais do grupo
INSERT INTO mestre.conteudo (id_mestre, chave_negocio, titulo, tipo, categoria, nivel,
                             carga_horaria_min, autor, descricao,
                             data_primeira_publicacao, data_ultima_versao,
                             conteudo_id_vencedor, qtd_registros_origem)
SELECT id_mestre,
       chave_negocio,
       (array_agg(titulo            ORDER BY posicao) FILTER (WHERE titulo            IS NOT NULL))[1],
       (array_agg(tipo              ORDER BY posicao) FILTER (WHERE tipo              IS NOT NULL))[1],
       (array_agg(categoria         ORDER BY posicao) FILTER (WHERE categoria         IS NOT NULL))[1],
       (array_agg(nivel             ORDER BY posicao) FILTER (WHERE nivel             IS NOT NULL))[1],
       (array_agg(carga_horaria_min ORDER BY posicao) FILTER (WHERE carga_horaria_min IS NOT NULL))[1],
       (array_agg(autor             ORDER BY posicao) FILTER (WHERE autor             IS NOT NULL))[1],
       (array_agg(descricao         ORDER BY posicao) FILTER (WHERE descricao         IS NOT NULL))[1],
       min(data_publicacao),
       max(data_publicacao),
       min(conteudo_id) FILTER (WHERE posicao = 1),
       count(*)
FROM mestre.vw_conteudo_sobrevivencia
GROUP BY id_mestre, chave_negocio;
