# Narrativa executiva e recomendação final (RF16 / RF34)

**Pergunta de negócio:** os usuários concluem o que começam, e as recomendações ajudam?
**Fonte:** camada Gold do pipeline governado (Bronze → Silver → Gold), painel
`painel_executivo` no Apache Superset.

Convenção: **Fato** = medido nos dados · **Hipótese** = explicação provável, não
comprovada · **Recomendação** = ação proposta.

## 1. Contexto

A plataforma tem **1.000 conteúdos** (cursos, vídeos, artigos e podcasts, em 8 categorias)
e **150 usuários**. Os dados passam por uma carga automatizada diária (06:00) que
valida, deduplica, testa a qualidade, protege os dados pessoais e publica a Gold e os
metadados. A carga completa leva menos de 1 minuto.

## 2. O que os dados mostram

- **Fato:** no último mês, **71 usuários** estiveram ativos e a **taxa de conclusão**
  (pares usuário-conteúdo com conclusão ÷ pares com alguma interação) foi de **22,68%**.
- **Fato:** **Segurança & Governança** tem a menor taxa de conclusão, **8,8%**, menos
  da metade de **Programação & Software** (**20,2%**).
- **Fato:** **cursos** concluem menos (**12,4%**) que os demais tipos (**~16%**), e
  conteúdos com **mais de 10 horas** ficam em **10,5%**.
- **Hipótese:** a baixa conclusão está ligada à **duração e densidade** do conteúdo
  (cursos longos), mais do que ao tema em si.

## 3. Descoberta: as recomendações não têm resultado mensurável

- **Fato:** **0 de 750** recomendações do lote mais recente têm interação registrada
  depois de geradas (taxa de conversão de 0%).
- **Hipótese:** o lote é recente, ou o sistema não registra a **origem** da interação
  (veio de uma recomendação ou não). Hoje **não é possível afirmar** se as
  recomendações funcionam; o problema é de **medição**, não necessariamente do modelo.

## 4. Confiabilidade dos dados

- **Fato:** em todas as cargas, **7,7%** das interações acontecem **antes** da data de
  publicação do conteúdo, acima do limite aceito de **5%**. O teste de qualidade Q04 gera
  **alerta** (sem bloquear), e há um alerta configurado no Superset.
- **Fato:** o catálogo tem **3 conteúdos cadastrados em duplicidade** (mesmo título,
  tipo, nível e autor, com ids diferentes), consolidados na tabela mestre (RF30).
- **Consequência:** os KPIs acima incluem essas interações inconsistentes; devem ser
  lidos com essa margem.

## 5. Governança e privacidade

- Nenhum dado pessoal real é usado; o cadastro de usuários é fictício.
- O dashboard **não acessa** dados pessoais: vê só pseudônimos, nome e e-mail
  mascarados, faixa etária e UF. O usuário do Superset não tem permissão nos schemas
  `lgpd`, `bronze` e `silver`.
- Catálogo, glossário, classificações LGPD e linhagem estão no OpenMetadata,
  atualizados a cada carga.

## 6. Recomendação final

| # | Ação | Por quê | Como medir |
|---|---|---|---|
| 1 | **Dividir cursos longos (> 10 h) em módulos**, começando por Segurança & Governança | menor taxa de conclusão e maior duração | taxa de conclusão da categoria no mês seguinte (meta: aproximar dos ~16% dos demais tipos) |
| 2 | **Registrar a origem da interação** (clique vindo de recomendação) | sem isso, a conversão é sempre 0% e o sistema de recomendação não pode ser avaliado | taxa de conversão > 0 medida no próximo lote |
| 3 | **Corrigir as datas de publicação na origem do catálogo** | 7,7% de interações inconsistentes distorcem os KPIs | teste Q04 abaixo de 5% (alerta deixa de disparar) |
| 4 | **Unificar os 3 conteúdos duplicados** no cadastro de origem | duplicidade divide as métricas de um mesmo conteúdo | `mestre.conteudo` sem grupos consolidados |

**Prioridade:** a ação **2** vem primeiro. Ela é barata e destrava a avaliação do
sistema de recomendação, que hoje é a maior incerteza do negócio. A ação **1** é a de
maior impacto esperado no engajamento, e a **3** aumenta a confiança em todos os
números do painel.
