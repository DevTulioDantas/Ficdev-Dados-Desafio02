-- RF30 - Remove os registros de teste e recalcula os dados mestres
DELETE FROM silver.catalogo_conteudos WHERE conteudo_id IN (9001, 9002);
