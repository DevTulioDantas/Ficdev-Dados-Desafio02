-- =====================================================================
-- Camada Silver — tabelas de dados e de quarentena (RF21, RF23)
-- Idempotente (IF NOT EXISTS): pode rodar quantas vezes for preciso.
--
-- Silver: tipos definidos, chave primária = chave de negócio usada na
-- deduplicação do pipeline. Sem FOREIGN KEY de propósito: o truncate
-- de uma tabela referenciada seria recusado; a integridade referencial
-- é garantida pelas regras de validação do Hop (INT02, COM02, REC03).
--
-- Quarentena: campos originais como TEXT (o registro chega como estava)
-- + diagnóstico do error handling + auditoria.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Catálogo
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.catalogo_conteudos
(
  conteudo_id             INTEGER PRIMARY KEY
, titulo                  TEXT
, tipo                    TEXT
, categoria               TEXT
, nivel                   TEXT
, carga_horaria_min       INTEGER
, data_publicacao         DATE
, descricao               TEXT
, autor                   TEXT
, data_hora_processamento TIMESTAMP
, id_execucao             TEXT
);

CREATE TABLE IF NOT EXISTS silver.rejeitados_catalogo
(
  conteudo_id TEXT, titulo TEXT, tipo TEXT, categoria TEXT, nivel TEXT
, carga_horaria_min TEXT, data_publicacao TEXT, descricao TEXT, autor TEXT
, qtd_erros SMALLINT, motivo_erro TEXT, campo_erro TEXT, codigo_erro TEXT
, pipeline_origem TEXT, data_hora_rejeicao TIMESTAMP, id_execucao TEXT
);

-- ---------------------------------------------------------------------
-- Interações
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.interacoes_usuarios
(
  usuario_id              INTEGER      NOT NULL
, conteudo_id             INTEGER      NOT NULL
, tipo_interacao          TEXT         NOT NULL
, data_hora               TIMESTAMP    NOT NULL
, tempo_consumido         INTEGER
, percentual_conclusao    NUMERIC(5,2)
, avaliacao_atribuida     SMALLINT
, data_hora_processamento TIMESTAMP
, id_execucao             TEXT
, PRIMARY KEY (usuario_id, conteudo_id, tipo_interacao, data_hora)
);

CREATE TABLE IF NOT EXISTS silver.rejeitados_interacoes
(
  usuario_id TEXT, conteudo_id TEXT, tipo_interacao TEXT, data_hora TEXT
, tempo_consumido TEXT, percentual_conclusao TEXT, avaliacao_atribuida TEXT
, qtd_erros SMALLINT, motivo_erro TEXT, campo_erro TEXT, codigo_erro TEXT
, pipeline_origem TEXT, data_hora_rejeicao TIMESTAMP, id_execucao TEXT
);

-- ---------------------------------------------------------------------
-- Comentários e avaliações
-- (a coluna "data" da fonte é renomeada para data_comentario na Silver)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.comentarios_avaliacoes
(
  usuario_id              INTEGER  NOT NULL
, conteudo_id             INTEGER  NOT NULL
, avaliacao               SMALLINT NOT NULL
, comentario              TEXT     NOT NULL
, tags                    TEXT              -- lista JSON como texto, ex.: ["etl","spark"]
, data_comentario         DATE     NOT NULL
, data_hora_processamento TIMESTAMP
, id_execucao             TEXT
, PRIMARY KEY (usuario_id, conteudo_id, data_comentario)
);

CREATE TABLE IF NOT EXISTS silver.rejeitados_comentarios
(
  usuario_id TEXT, conteudo_id TEXT, avaliacao TEXT, comentario TEXT
, tags TEXT, "data" TEXT
, qtd_erros SMALLINT, motivo_erro TEXT, campo_erro TEXT, codigo_erro TEXT
, pipeline_origem TEXT, data_hora_rejeicao TIMESTAMP, id_execucao TEXT
);

-- ---------------------------------------------------------------------
-- Recomendações
-- Chave de negócio: (data_geracao, usuario_id, posicao) — cada execução
-- do motor (lote = data_geracao) gera um top-5 por usuário.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS silver.recomendacao
(
  recomendacao_id         BIGINT
, usuario_id              INTEGER      NOT NULL
, conteudo_id             INTEGER      NOT NULL
, pontuacao               NUMERIC(5,2)
, posicao                 SMALLINT     NOT NULL
, status                  TEXT
, data_geracao            TIMESTAMP    NOT NULL
, data_hora_processamento TIMESTAMP
, id_execucao             TEXT
, PRIMARY KEY (data_geracao, usuario_id, posicao)
);

CREATE TABLE IF NOT EXISTS silver.rejeitados_recomendacao
(
  recomendacao_id TEXT, usuario_id TEXT, conteudo_id TEXT, pontuacao TEXT
, posicao TEXT, status TEXT, data_geracao TIMESTAMP
, qtd_erros SMALLINT, motivo_erro TEXT, campo_erro TEXT, codigo_erro TEXT
, pipeline_origem TEXT, data_hora_rejeicao TIMESTAMP, id_execucao TEXT
);
