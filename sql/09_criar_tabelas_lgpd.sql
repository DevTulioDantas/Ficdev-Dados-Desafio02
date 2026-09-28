-- =====================================================================
-- Schema lgpd (RF32 / RF33) - dados pessoais FICTICIOS e sua protecao
--
-- ACESSO RESTRITO: o usuario superset_leitura NAO tem permissao neste
-- schema (ver sql/06_criar_usuario_superset.sql). O dashboard so enxerga
-- a Gold, que recebe apenas pseudonimos e valores mascarados.
--
-- Tabelas:
--   lgpd.usuario_cadastro     cadastro ficticio (dados pessoais e 1 sensivel)
--   lgpd.usuario_pseudonimo   tabela de correspondencia usuario_id <-> pseudonimo
--   lgpd.usuario_protegido    pseudonimo + campos mascarados, hash e generalizados
--
-- Preenchidas por lgpd/proteger_dados_pessoais.py (chave e salt no .env).
-- Idempotente.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS lgpd;
COMMENT ON SCHEMA lgpd IS 'Dados pessoais ficticios (RF32/RF33) - acesso restrito';

CREATE TABLE IF NOT EXISTS lgpd.usuario_cadastro (
    usuario_id                 INTEGER PRIMARY KEY,
    nome                       TEXT NOT NULL,
    email                      TEXT NOT NULL UNIQUE,
    cpf                        TEXT NOT NULL,
    telefone                   TEXT,
    data_nascimento            DATE,
    cidade                     TEXT,
    uf                         CHAR(2),
    necessidade_acessibilidade TEXT,
    data_cadastro              DATE
);
COMMENT ON TABLE lgpd.usuario_cadastro IS
    'Cadastro FICTICIO gerado por script (nenhum dado real). CPF com digito verificador propositalmente invalido.';
COMMENT ON COLUMN lgpd.usuario_cadastro.necessidade_acessibilidade IS
    'Dado pessoal SENSIVEL (saude, LGPD art. 5, II) - nao sai do schema lgpd';

CREATE TABLE IF NOT EXISTS lgpd.usuario_pseudonimo (
    usuario_id    INTEGER PRIMARY KEY,
    pseudonimo    VARCHAR(20) NOT NULL UNIQUE,
    data_geracao  TIMESTAMP DEFAULT now()
);
COMMENT ON TABLE lgpd.usuario_pseudonimo IS
    'Tabela de correspondencia (reidentificacao controlada). Fica so no banco, nunca no repositorio.';

CREATE TABLE IF NOT EXISTS lgpd.usuario_protegido (
    pseudonimo      VARCHAR(20) PRIMARY KEY,
    nome_mascarado  TEXT,
    email_mascarado TEXT,
    email_hash      CHAR(64),
    faixa_etaria    TEXT,
    uf              CHAR(2),
    data_hora_processamento TIMESTAMP DEFAULT now()
);
COMMENT ON TABLE lgpd.usuario_protegido IS
    'Versao protegida do cadastro: pseudonimo, mascaras, hash com salt e atributos generalizados';
