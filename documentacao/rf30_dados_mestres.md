# Dados mestres de conteúdo (RF30)

Implementação: `sql/08_dados_mestres_conteudo.sql`, executado pela action
**Dados mestres conteudo** do workflow `carga_completa.hwf` (depois da Silver,
antes dos testes de qualidade). Padrão ELT: SQL dentro do PostgreSQL, schema `mestre`.

## 1. Entidade, chave, atributos e fonte

| Item | Definição |
|---|---|
| Entidade mestre | **Conteúdo** (curso, vídeo, artigo, podcast) |
| Fonte de referência | `silver.catalogo_conteudos`: o catálogo oficial (CSV do Desafio 1), já validado pela Silver |
| Chave de negócio | título + tipo + nível + autor, todos **normalizados** |
| Atributos essenciais | título, tipo, categoria, nível, carga horária, data de publicação, autor, descrição |
| Identificador mestre | `id_mestre` = `MC-` + menor `conteudo_id` do grupo (ex.: `MC-000039`); estável entre execuções |

**Por que essa chave:**

- **Título sozinho não identifica o conteúdo:** 189 títulos repetidos no catálogo
  pertencem a autores diferentes (conteúdos distintos).
- **O nível diferencia produtos:** o mesmo curso do mesmo autor em nível Básico
  (462 min) e Avançado (1.745 min) são ofertas diferentes e não podem ser fundidos.
- **O `conteudo_id` não serve como chave de negócio:** é o identificador técnico da
  fonte, e o problema é justamente o mesmo conteúdo cadastrado com ids diferentes.

## 2. Regras

### Correspondência (matching)

Dois registros são o **mesmo conteúdo** quando têm a mesma chave de negócio depois da
normalização:

| Normalização | Exemplo |
|---|---|
| minúsculas, sem acentos, sem pontuação, espaços únicos | `FUNDAMENTOS DE GOVERNANÇA` → `fundamentos de governanca` |
| autor sem título acadêmico ou profissional (Prof., Profa., Dr., Dra., Eng.) | `Profa. Marina Alves Costa` → `marina alves costa` |

### Deduplicação

Cada grupo de registros correspondentes gera **um** registro mestre; todos os
`conteudo_id` do grupo ficam na tabela de correspondência apontando para ele.

### Sobrevivência (survivorship)

| Regra | Aplicação |
|---|---|
| 1. Registro vencedor | a **versão mais recente** (maior `data_publicacao`), por refletir o cadastro atual |
| 2. Desempate | o registro **mais completo** (mais atributos preenchidos) e, depois, o menor `conteudo_id` (o cadastro original) |
| 3. Atributos vazios | um atributo nulo no vencedor é **preenchido** pelo próximo registro do grupo que o tenha |
| 4. Datas | `data_primeira_publicacao` = a mais antiga do grupo; `data_ultima_versao` = a mais recente |

## 3. Tabelas geradas

| Objeto | Conteúdo |
|---|---|
| `mestre.conteudo` | registro mestre (*golden record*), um por conteúdo real |
| `mestre.conteudo_correspondencia` | de/para `conteudo_id` → `id_mestre`, com `vencedor` e `motivo` |
| `mestre.vw_conteudo_sobrevivencia` | auditoria: chave, completude e posição de cada registro no seu grupo |

Resultado nos dados reais: **1.000 conteúdos → 997 registros mestres**
(3 grupos consolidados: o mesmo conteúdo, no mesmo nível, com ids diferentes).
É uma duplicidade que a Silver não detecta, porque deduplica pelo `conteudo_id`.

## 4. Demonstração: dois registros conflitantes

Scripts em `sql/testes/`: `rf30_injetar_conflito.sql` → `08_dados_mestres_conteudo.sql`
→ `rf30_conferir_conflito.sql` → `rf30_limpar_conflito.sql`.
Evidência: `documentacao/evidencias/rf30_conflito_conteudo.txt`.

| Atributo | Registro 9001 (cadastro antigo) | Registro 9002 (versão revisada) | Registro mestre `MC-009001` | Regra |
|---|---|---|---|---|
| título | FUNDAMENTOS DE GOVERNANÇA DE DADOS COM LGPD | Fundamentos de Governança de Dados com LGPD | **do 9002** | vencedor (mais recente) |
| autor | Profa. Marina Alves Costa | Marina Alves Costa | **do 9002** | vencedor |
| carga horária | 600 min | 720 min | **720 min** | vencedor |
| data de publicação | 2025-03-10 | 2026-02-15 | 1ª: **2025-03-10** · última: **2026-02-15** | regra de datas |
| descrição | preenchida | vazia | **do 9001** | preenchimento de vazios |
| correspondência | → MC-009001 (não vencedor) | → MC-009001 (vencedor) | 2 registros de origem | mesma chave normalizada |

## 5. Limitações e evolução

- Correspondência **exata** sobre a chave normalizada: não detecta erros de digitação
  ("Govenança"). A evolução seria similaridade de texto (ex.: `pg_trgm`) com revisão
  humana dos casos duvidosos.
- A Gold continua usando `conteudo_id`; com a tabela de correspondência, os KPIs
  podem ser agregados por `id_mestre` quando o negócio decidir consolidar as versões.
