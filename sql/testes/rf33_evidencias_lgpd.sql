-- RF32 / RF33 - evidencias da protecao de dados pessoais
-- Nao exibe pares usuario_id <-> pseudonimo (a correspondencia nao sai do banco).

\echo '== 1) Volumes =='
SELECT (SELECT count(*) FROM lgpd.usuario_cadastro) AS cadastros_ficticios,
       (SELECT count(*) FROM lgpd.usuario_cadastro WHERE necessidade_acessibilidade IS NOT NULL) AS com_dado_sensivel,
       (SELECT count(*) FROM lgpd.usuario_pseudonimo) AS pseudonimos,
       (SELECT count(*) FROM lgpd.usuario_protegido) AS protegidos,
       (SELECT count(*) FROM gold.dim_usuario) AS usuarios_na_gold;

\echo '== 2) Cadastro FICTICIO (schema lgpd, acesso restrito) - amostra =='
SELECT nome, email, cpf, telefone, data_nascimento, cidade, uf, necessidade_acessibilidade
FROM lgpd.usuario_cadastro ORDER BY nome LIMIT 3;

\echo '== 3) O que chega ao dashboard (gold.dim_usuario) - amostra =='
SELECT usuario_pseudonimo, nome_mascarado, email_mascarado, faixa_etaria, uf
FROM gold.dim_usuario ORDER BY nome_mascarado LIMIT 3;

\echo '== 4) Hash com salt do e-mail (64 hex, irreversivel) - amostra =='
SELECT email_mascarado, email_hash, length(email_hash) AS tamanho
FROM lgpd.usuario_protegido ORDER BY email_mascarado LIMIT 2;

\echo '== 5) Minimizacao: colunas de usuario nas tabelas Gold (nenhum usuario_id) =='
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema = 'gold' AND column_name LIKE 'usuario%' ORDER BY 1, 2;

\echo '== 6) Campos do cadastro que NAO chegam a Gold =='
SELECT c.column_name AS campo_do_cadastro,
       EXISTS (SELECT 1 FROM information_schema.columns g
               WHERE g.table_schema = 'gold' AND g.column_name = c.column_name) AS existe_na_gold
FROM information_schema.columns c
WHERE c.table_schema = 'lgpd' AND c.table_name = 'usuario_cadastro'
ORDER BY c.ordinal_position;

\echo '== 7) Permissao do usuario do dashboard =='
SELECT s.schema_name, has_schema_privilege('superset_leitura', s.schema_name, 'USAGE') AS superset_leitura_acessa
FROM information_schema.schemata s
WHERE s.schema_name IN ('lgpd', 'bronze', 'silver', 'gold', 'qualidade')
ORDER BY 2 DESC, 1;
