# Regras dos testes de qualidade (RF31)

Fonte da verdade: `sql/03_criar_tabelas_qualidade.sql` (tabela `qualidade.regras_testes`).
Execução: `sql/04_executar_testes_qualidade.sql`, action **Testes de qualidade** do
workflow `carga_completa.hwf`, depois da Silver e antes da Gold. Cada execução grava
um resultado por teste em `qualidade.resultados_testes`, com o mesmo `id_execucao`
da carga.

| Teste | Dimensão | O que mede | Fonte | Regra de aprovação | Severidade | Ação se reprovar |
|---|---|---|---|---|---|---|
| Q01 | Completude | % de conteúdos com descrição preenchida | `silver.catalogo_conteudos` | ≥ 95% | ALERTA | registrar ressalva e acionar o responsável pelo catálogo |
| Q02 | Validade | % de recomendações com pontuação entre 0 e 100 | `silver.recomendacao` | ≥ 100% | CRÍTICA | bloquear a publicação da Gold |
| Q03 | Unicidade | `conteudo_id` duplicados no catálogo | `silver.catalogo_conteudos` | = 0 registros | CRÍTICA | bloquear a publicação da Gold |
| Q04 | Consistência | % de interações anteriores à publicação do conteúdo | `silver.interacoes_usuarios` | ≤ 5% | ALERTA | registrar ressalva e investigar a origem das datas |
| Q05 | Integridade referencial | interações com `conteudo_id` inexistente no catálogo | `silver.interacoes_usuarios` | = 0 registros | CRÍTICA | bloquear a publicação da Gold |

## Como a severidade age no workflow

| Situação | Caminho no workflow | Estado final | Código de saída |
|---|---|---|---|
| todos aprovados | Críticos aprovados → Gold → Alertas aprovados → Log sucesso | sucesso | 0 |
| algum ALERTA reprovado | … → Alertas aprovados (falso) → Log ressalvas | sucesso com ressalvas | 0 |
| algum CRÍTICO reprovado | Críticos aprovados (falso) → Log bloqueio qualidade → Abort | falha, **Gold não publicada** | 1 |

## Resultados

- Resultado dos 5 testes e demonstração do bloqueio (limite do Q02 forçado para 101):
  `documentacao/evidencias/rf31_resultados_qualidade.txt`.
- Situação atual: Q01, Q02, Q03 e Q05 aprovados; **Q04 reprovado com 7,7%** (limite 5%),
  o que gera "sucesso com ressalvas" em todas as cargas.
- Evolução por execução: gráfico `evolucao_qualidade` do painel `painel_executivo`
  e alerta `alerta_qualidade_q04` no Superset.
- Para mudar um limite, altere a linha em `sql/03_criar_tabelas_qualidade.sql`
  (o `INSERT … ON CONFLICT` atualiza a regra) e rode a carga.
