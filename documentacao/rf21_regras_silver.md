# Regras da camada Silver (RF21)

A Silver recebe os dados **como chegaram** na Bronze (todos os campos como texto)
e entrega dados **tipados, padronizados, validados e sem duplicidade**.
Nenhum registro é descartado em silêncio: o que não passa nas regras vai para a
quarentena (`silver.rejeitados_*`) com o motivo, o campo e o código do erro (RF23).

Pipelines: `hop/pipelines/silver_catalogo.hpl`, `silver_interacoes.hpl`,
`silver_comentarios.hpl`, `silver_recomendacao.hpl`, executados pelo workflow
`carga_completa.hwf` nessa ordem (o catálogo vem primeiro porque as outras três
validam `conteudo_id` contra `silver.catalogo_conteudos`).

## 1. Fluxo comum aos quatro pipelines

```
Bronze ─► Limpar textos ─► Validar regras ─┬─► Converter tipos ─┬─► Ordenar ─► Deduplicar ─► auditoria ─► silver.<tabela>
                                           │                    │
                                           └── erro ────────────┴── erro ─► Origem do erro ─► Padronizar codigo
                                                                            ─► Limpar mensagem ─► auditoria ─► silver.rejeitados_<tabela>
```

| Etapa | Transform do Hop | O que faz |
|---|---|---|
| Limpar textos | String operations | `trim` (início e fim) em **todos** os campos de texto |
| Validar regras | Data validator | aplica as regras da seção 3; *validate all* ligado: registra **todos** os erros da linha, separados por ` \| ` |
| Converter tipos | Select values | converte texto em Integer, Number e Date com máscara fixa |
| Ordenar + Deduplicar | Sort rows + Unique rows | remove duplicidades pela chave de negócio (seção 4) |
| Auditoria | System info + Get variable | `data_hora_processamento` e `id_execucao` (mesmo ID do workflow) |
| Gravação | Table output | *truncate + insert*: a Silver é recalculada inteira a cada carga (idempotente) |

Os erros das duas etapas que validam (Validar regras e Converter tipos) seguem pelo
*error handling* do Hop e recebem, antes de gravar na quarentena:

- `pipeline_origem`: nome do pipeline;
- **Padronizar codigo**: o código genérico `SELECT001` (falha de conversão de tipo)
  vira o código da tabela (`CAT08`, `INT08`, `COM07`, `REC08`);
- **Limpar mensagem**: retira espaços nas pontas e troca quebras de linha por `;`,
  para a mensagem caber numa linha da tabela;
- `data_hora_rejeicao` e `id_execucao`.

## 2. Valores ausentes

Regra geral: **campo obrigatório vazio vai para a quarentena**; campo opcional
vazio segue para a Silver como `NULL`. Como o `trim` roda antes da validação,
um texto só com espaços é tratado como vazio.

| Tabela | Campos que **podem** ficar nulos | Motivo |
|---|---|---|
| catálogo | nenhum (`descricao` e `autor` não são validados e passam como vieram) | todos os campos validados são obrigatórios |
| interações | `percentual_conclusao`, `avaliacao_atribuida` | só existem para alguns tipos de interação (ex.: nota só em `avaliação`) |
| comentários | `tags` | comentário sem tags é válido |
| recomendação | nenhum | todos os campos são obrigatórios |

Não há imputação (preencher com média, zero ou valor padrão): um valor ausente
permanece ausente, para não criar informação que a fonte não tem.

## 3. Regras de validação e padronização

### Catálogo (`silver.catalogo_conteudos`)

| Código | Campo | Regra |
|---|---|---|
| CAT01 | `conteudo_id` | obrigatório, só dígitos (`^[0-9]+$`) |
| CAT02 | `titulo` | obrigatório |
| CAT03 | `tipo` | lista: Curso, Vídeo, Artigo, Podcast |
| CAT04 | `categoria` | lista: Banco de Dados, Business Intelligence, Ciência de Dados, DevOps & Cloud, Engenharia de Dados, Inteligência Artificial, Programação & Software, Segurança & Governança |
| CAT05 | `nivel` | lista: Básico, Intermediário, Avançado |
| CAT06 | `carga_horaria_min` | inteiro positivo (`^[1-9][0-9]*$`) |
| CAT07 | `data_publicacao` | data `yyyy-MM-dd` |
| CAT08 | qualquer | falha na conversão de tipo |

Tipos na Silver: `conteudo_id` e `carga_horaria_min` Integer; `data_publicacao` Date.

### Interações (`silver.interacoes_usuarios`)

| Código | Campo | Regra |
|---|---|---|
| INT01 | `usuario_id` | deve existir em `public.usuario` (cadastro do Desafio 1) |
| INT02 | `conteudo_id` | deve existir em `silver.catalogo_conteudos` |
| INT03 | `tipo_interacao` | lista: visualização, início, conclusão, curtida, avaliação, compartilhamento |
| INT04 | `data_hora` | `yyyy-MM-ddTHH:mm:ss` |
| INT05 | `tempo_consumido` | inteiro positivo |
| INT06 | `percentual_conclusao` | opcional; se preenchido, de 0 a 100 |
| INT07 | `avaliacao_atribuida` | opcional; se preenchida, de 1 a 5 |
| INT08 | qualquer | falha na conversão de tipo |

Tipos: ids, `tempo_consumido` e `avaliacao_atribuida` Integer; `percentual_conclusao` Number; `data_hora` Date/hora.

### Comentários e avaliações (`silver.comentarios_avaliacoes`)

| Código | Campo | Regra |
|---|---|---|
| COM01 | `usuario_id` | deve existir em `public.usuario` |
| COM02 | `conteudo_id` | deve existir em `silver.catalogo_conteudos` |
| COM03 | `avaliacao` | de 1 a 5 |
| COM04 | `comentario` | obrigatório |
| COM05 | `tags` | opcional; se preenchido, lista JSON (`[...]`) |
| COM06 | `data` | `yyyy-MM-dd` (na Silver: `data_comentario`) |
| COM07 | qualquer | falha na conversão de tipo |

### Recomendação (`silver.recomendacao`)

| Código | Campo | Regra |
|---|---|---|
| REC01 | `recomendacao_id` | obrigatório, só dígitos |
| REC02 | `usuario_id` | deve existir em `public.usuario` |
| REC03 | `conteudo_id` | deve existir em `silver.catalogo_conteudos` |
| REC04 | `pontuacao` | de 0 a 100 |
| REC05 | `posicao` | de 1 a 5 |
| REC06 | `status` | lista: positivo, estavel, negativo |
| REC07 | `data_geracao` | obrigatória |
| REC08 | qualquer | falha na conversão de tipo |

## 4. Deduplicação (chave de negócio)

| Tabela | Chave | Observação |
|---|---|---|
| catálogo | `conteudo_id` | títulos repetidos **não** são duplicidade: 189 títulos iguais pertencem a conteúdos distintos (insumo para dados mestres, RF30) |
| interações | `usuario_id`, `conteudo_id`, `tipo_interacao`, `data_hora` | o mesmo evento registrado duas vezes |
| comentários | `usuario_id`, `conteudo_id`, `data_comentario` | um comentário por usuário, conteúdo e dia |
| recomendação | `data_geracao`, `usuario_id`, `posicao` | os 3 lotes de geração são mantidos na Silver; a Gold usa só o mais recente |

Havendo duplicidade, fica a primeira linha após a ordenação pela chave.

## 5. Decisões conscientes

- **Interações antes da publicação do conteúdo** (77 casos, 7,7%) **não** são
  rejeitadas na Silver: a data da interação é válida isoladamente. A
  inconsistência é medida pelo teste de qualidade Q04 (ALERTA, limite 5%) e
  exibida no dashboard (RF31).
- **Integridade referencial na Silver**: usuário e conteúdo inexistentes vão para
  a quarentena, e não para a Gold, para os KPIs não contarem registros órfãos.
- **Silver recalculada inteira** (*truncate*): não há carga parcial; se uma etapa
  falha, o workflow para antes da Gold (RF22/RF23).

## 6. Evidências

| Tabela Silver | Linhas | Rejeitados |
|---|---|---|
| `catalogo_conteudos` | 1.000 | 0 |
| `interacoes_usuarios` | 1.000 | 0 |
| `comentarios_avaliacoes` | 1.000 | 0 |
| `recomendacao` | 2.250 | 0 |

Os dados de origem não têm erros; a quarentena foi demonstrada injetando erros
(`sql/testes/rf23_*.sql`, evidências em `documentacao/evidencias/rf23_*.txt`).
