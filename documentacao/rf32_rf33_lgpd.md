# LGPD: inventário e proteção de dados pessoais (RF32 e RF33)

> **Nenhum dado pessoal real é usado.** O cadastro de usuários é gerado por
> `lgpd/proteger_dados_pessoais.py`: nomes de listas genéricas, e-mails no domínio
> reservado `exemplo.com`, telefones na faixa fictícia `(65) 90000-xxxx` e CPFs com
> **dígito verificador propositalmente inválido** (têm formato de CPF, mas nunca
> são um CPF válido). Os nomes de autores do catálogo também são fictícios.
>
> Prazos e bases legais abaixo são **propostas** para o desafio, não parecer jurídico.

## 1. Onde ficam os dados pessoais

| Schema | Conteúdo | Quem acessa |
|---|---|---|
| `lgpd` | cadastro fictício, tabela de correspondência pseudônimo ↔ `usuario_id`, versão protegida | só o pipeline (usuário `postgres`) |
| `bronze`, `silver` | `usuario_id` nas interações, comentários e recomendações; `autor` no catálogo | pipeline e equipe de dados |
| `gold` | **sem `usuario_id`**: só pseudônimo, nome e e-mail mascarados, faixa etária e UF | pipeline e `superset_leitura` (dashboard) |

O usuário do dashboard (`superset_leitura`) só tem permissão em `gold` e
`qualidade`. Uma consulta ao schema `lgpd` ou à Silver devolve `permission denied`.

## 2. Inventário de campos (RF32)

Classificação: **DP** = dado pessoal (identifica a pessoa) · **DPS** = dado pessoal
sensível (LGPD art. 5º, II) · **II** = identificador indireto (identifica em
combinação com outros dados) · **TL** = texto livre (pode conter dado pessoal).

| Campo | Onde | Classe | Finalidade | Necessidade | Acesso | Retenção proposta | Tratamento na Gold |
|---|---|---|---|---|---|---|---|
| `nome` | lgpd.usuario_cadastro | DP | identificar o aluno no atendimento e no certificado | necessário para o serviço | suporte e pipeline | enquanto a conta existir + 6 meses | **mascarado** (`J***** C****`) |
| `email` | lgpd.usuario_cadastro | DP | login e comunicação | necessário para o serviço | suporte e pipeline | enquanto a conta existir + 6 meses | **mascarado** (`j*****@exemplo.com`); **hash com salt** só no schema lgpd |
| `cpf` | lgpd.usuario_cadastro | DP | emissão de certificado | só na emissão | suporte | enquanto a conta existir + 5 anos (certificados) | **não entra** |
| `telefone` | lgpd.usuario_cadastro | DP | contato opcional | não é necessário para a análise | suporte | enquanto a conta existir | **não entra** |
| `data_nascimento` | lgpd.usuario_cadastro | DP | perfil etário | só a faixa é necessária | pipeline | enquanto a conta existir | **generalizado** em faixa etária |
| `cidade`, `uf` | lgpd.usuario_cadastro | II | perfil regional | UF é suficiente | pipeline | enquanto a conta existir | só **UF** |
| `necessidade_acessibilidade` | lgpd.usuario_cadastro | **DPS** (saúde) | adaptar o conteúdo (legendas, contraste) | só para a plataforma, não para análise | suporte, com consentimento | enquanto houver consentimento | **não entra** |
| `data_cadastro` | lgpd.usuario_cadastro | DP (vinculado) | tempo de conta | baixa | pipeline | enquanto a conta existir | não entra |
| `usuario_id` | bronze, silver, lgpd | II | ligar interações, comentários e recomendações ao usuário | necessário até a Silver | pipeline e equipe de dados | enquanto a conta existir | **pseudonimizado** |
| `data_hora`, `tempo_consumido`, `percentual_conclusao`, `avaliacao_atribuida` | interações | DP (comportamento vinculado ao `usuario_id`) | KPIs de engajamento | necessário | equipe de dados, dashboard | 24 meses detalhado; depois só agregado | ligado ao **pseudônimo** |
| `comentario`, `tags` | comentários | TL | análise de satisfação | necessário | equipe de dados | enquanto o comentário estiver publicado | não entra |
| `autor` | catálogo | DP (nome de pessoa natural, fictício) | créditos do conteúdo | não é necessário aos KPIs | pipeline | enquanto o conteúdo existir | **não entra** (`dim_conteudo` exclui) |
| `pseudonimo` ↔ `usuario_id` | lgpd.usuario_pseudonimo | II (reidentificável) | associação controlada | necessário para a Gold | só o pipeline | igual ao cadastro | a Gold recebe só o pseudônimo |

**Classificação no catálogo:** as tags `LGPD.DadoPessoal`, `LGPD.DadoPessoalSensivel`,
`LGPD.IdentificadorIndireto` e `LGPD.NaoPessoal` estão em `openmetadata/governanca.yaml`
(RF28/RF32). As tabelas do schema `lgpd` e as colunas novas da Gold seguem as classes
da tabela acima.

### Minimização na Gold

| Antes | Depois |
|---|---|
| `usuario_id` em `dim_usuario`, `fato_interacoes` e `fato_recomendacao` | `usuario_pseudonimo` (HMAC); nenhuma tabela Gold guarda `usuario_id` |
| sem atributos de perfil | só **faixa etária** e **UF** (generalizados) e nome/e-mail **mascarados** |
| — | CPF, telefone, data de nascimento, cidade e o dado sensível **não chegam** à Gold |

## 3. Técnicas aplicadas (RF33)

| Técnica | Campo | Como | Resultado |
|---|---|---|---|
| **Mascaramento** | nome e e-mail na `gold.dim_usuario` | primeira letra + `*` | `Eduarda Toledo Costa` → `E****** T***** C****`; `eduarda.costa1@exemplo.com` → `e*****@exemplo.com` |
| **Pseudonimização** | `usuario_id` em toda a Gold | HMAC-SHA256 com a chave `LGPD_CHAVE_PSEUDONIMO` | `1` → `U0350e6768c370eab` (exemplo); a correspondência fica em `lgpd.usuario_pseudonimo` |
| **Hash com salt** | e-mail | SHA-256 de `salt + e-mail normalizado`, com o salt `LGPD_SALT_HASH` | 64 caracteres hexadecimais em `lgpd.usuario_protegido.email_hash` |
| Generalização (complementar) | data de nascimento, cidade | faixa etária; só UF | `1976-06-11` → `45-59` |

### Comparação e justificativa

| | Pseudonimização (HMAC + tabela de correspondência) | Hash com salt (SHA-256) |
|---|---|---|
| Reversível? | **sim, de forma controlada:** quem tem acesso a `lgpd.usuario_pseudonimo` volta ao `usuario_id` | **não:** não há tabela de volta; só se compara |
| Para que serve | manter a **associação** entre fatos do mesmo usuário (interações, recomendações, dimensão) sem expor o id | **comparar** um valor informado com a base (o e-mail já está cadastrado?) sem guardar o original |
| Por que neste campo | a Gold precisa contar usuários distintos e cruzar fatos: o identificador tem de continuar consistente | o e-mail é dado direto; para análise basta saber se "é o mesmo", nunca qual é |
| Segredo | chave HMAC no `.env`: sem ela ninguém recalcula o pseudônimo a partir de um id | salt no `.env`: impede ataque de dicionário e tabelas pré-calculadas |
| Status na LGPD | continua **dado pessoal** (art. 13, § 4º): a reidentificação é possível | tratado como irreversível, mas o conjunto ainda exige cuidado se combinado com outros dados |

**Mascaramento** é a terceira técnica: é só para **exibição**. O dashboard mostra que o
registro existe sem revelar o valor, e não serve para ligar nem comparar dados.

Demonstração da comparação por hash (o e-mail original nunca é lido):

```powershell
python lgpd\proteger_dados_pessoais.py --verificar-email EDUARDA.COSTA1@exemplo.com
python lgpd\proteger_dados_pessoais.py --verificar-email alguem@exemplo.com
```

## 4. Segredos fora do código e do repositório

| Item | Onde fica | Versionado? |
|---|---|---|
| chave de pseudonimização `LGPD_CHAVE_PSEUDONIMO` | `.env` | ❌ (`.env.example` só com o nome da variável) |
| salt `LGPD_SALT_HASH` | `.env` | ❌ |
| tabela de correspondência | `lgpd.usuario_pseudonimo`, só no banco | ❌ (nunca exportada) |
| cadastro fictício | `lgpd.usuario_cadastro`, gerado pelo script | ❌ (recriado pelo script) |

Se a chave ou o salt estiverem ausentes (ou tiverem menos de 16 caracteres), o
script para com erro e o workflow aborta antes da Gold. Trocar a chave gera
pseudônimos novos: é o procedimento de **rotação**, e a Gold é recalculada inteira na
carga seguinte.

## 5. Execução no pipeline

Action **Proteger dados pessoais** do `carga_completa.hwf`, depois da Silver e dos
dados mestres e antes dos testes de qualidade e da Gold. Uma falha leva ao *Log erro*
e aborta a carga, porque a Gold depende do pseudônimo.

## 6. Evidências

- `documentacao/evidencias/rf33_lgpd_protecao.txt`: cadastro fictício x versão
  protegida x Gold, e a verificação por hash.
- `superset/exportacao_e_evidencias/rf33_sqllab_lgpd_bloqueado.png`: `permission denied`
  ao consultar `lgpd.usuario_cadastro` pelo SQL Lab.
- `superset/exportacao_e_evidencias/rf33_dashboard_dados_protegidos.png`: o dashboard só
  mostra pseudônimos e valores mascarados.
