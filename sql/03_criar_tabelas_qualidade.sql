-- =====================================================================
-- Qualidade de dados (RF31) - schema, regras e resultados
-- Idempotente: pode rodar quantas vezes for preciso.
--
-- qualidade.regras_testes     : catalogo dos testes (formula, limite,
--                               severidade e acao de cada um)
-- qualidade.resultados_testes : resultado de cada teste em cada execucao
--                               (historico usado para mostrar a evolucao
--                               das metricas)
--
-- Severidade:
--   CRITICA : reprovacao bloqueia a publicacao da camada Gold
--   ALERTA  : reprovacao gera "sucesso com ressalvas"
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS qualidade;

COMMENT ON SCHEMA qualidade IS 'Testes de qualidade de dados: regras e resultados por execucao';

CREATE TABLE IF NOT EXISTS qualidade.regras_testes
(
  teste_id    TEXT PRIMARY KEY
, dimensao    TEXT NOT NULL
, descricao   TEXT NOT NULL
, fonte       TEXT NOT NULL
, formula     TEXT NOT NULL
, operador    TEXT NOT NULL CHECK (operador IN ('>=', '<=', '='))
, limite      NUMERIC(10,2) NOT NULL
, unidade     TEXT NOT NULL
, severidade  TEXT NOT NULL CHECK (severidade IN ('CRITICA', 'ALERTA'))
, acao        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS qualidade.resultados_testes
(
  id_execucao            TEXT NOT NULL
, teste_id               TEXT NOT NULL
, fonte                  TEXT NOT NULL
, total_registros        INTEGER NOT NULL
, registros_com_problema INTEGER NOT NULL
, valor_medido           NUMERIC(10,2) NOT NULL
, limite                 NUMERIC(10,2) NOT NULL
, severidade             TEXT NOT NULL
, resultado              TEXT NOT NULL CHECK (resultado IN ('APROVADO', 'REPROVADO'))
, data_hora_teste        TIMESTAMP NOT NULL
, PRIMARY KEY (id_execucao, teste_id)
);

-- Regras: inseridas ou atualizadas (mudar um limite aqui e rodar de novo)
INSERT INTO qualidade.regras_testes
  (teste_id, dimensao, descricao, fonte, formula, operador, limite, unidade, severidade, acao)
VALUES
  ('Q01', 'Completude',
   'Conteudos do catalogo com descricao preenchida',
   'silver.catalogo_conteudos',
   '100 * conteudos com descricao nao vazia / total de conteudos',
   '>=', 95, '%', 'ALERTA',
   'Registrar ressalva e acionar o responsavel pelo catalogo')

, ('Q02', 'Validade',
   'Recomendacoes com pontuacao entre 0 e 100',
   'silver.recomendacao',
   '100 * recomendacoes com pontuacao entre 0 e 100 / total de recomendacoes',
   '>=', 100, '%', 'CRITICA',
   'Bloquear a publicacao da Gold')

, ('Q03', 'Unicidade',
   'Conteudos com conteudo_id duplicado na Silver',
   'silver.catalogo_conteudos',
   'total de conteudos - quantidade de conteudo_id distintos',
   '=', 0, 'registros', 'CRITICA',
   'Bloquear a publicacao da Gold')

, ('Q04', 'Consistencia',
   'Interacoes registradas antes da publicacao do conteudo',
   'silver.interacoes_usuarios',
   '100 * interacoes com data anterior a data_publicacao do conteudo / total de interacoes',
   '<=', 5, '%', 'ALERTA',
   'Registrar ressalva e investigar a origem das datas')

, ('Q05', 'Integridade referencial',
   'Interacoes que apontam para conteudo inexistente no catalogo',
   'silver.interacoes_usuarios',
   'quantidade de interacoes cujo conteudo_id nao existe em silver.catalogo_conteudos',
   '=', 0, 'registros', 'CRITICA',
   'Bloquear a publicacao da Gold')
ON CONFLICT (teste_id) DO UPDATE SET
  dimensao   = EXCLUDED.dimensao
, descricao  = EXCLUDED.descricao
, fonte      = EXCLUDED.fonte
, formula    = EXCLUDED.formula
, operador   = EXCLUDED.operador
, limite     = EXCLUDED.limite
, unidade    = EXCLUDED.unidade
, severidade = EXCLUDED.severidade
, acao       = EXCLUDED.acao;
