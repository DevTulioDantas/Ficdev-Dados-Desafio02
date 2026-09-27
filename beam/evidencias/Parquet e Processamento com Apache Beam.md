# RF24 e RF25 — Parquet e processamento com Apache Beam

Desafio Prático 2 · FIC_DEV — Fundamentos de Dados para IA
Medições realizadas em 27/09/2026, numa única máquina Windows (notebook de desenvolvimento), com Apache Hop 2.19.0 e Java 21.

> **Sobre a ausência de `beam/pipeline.py`:** o pipeline Apache Beam deste projeto foi implementado no **Apache Hop** (`hop/pipelines/engajamento_beam.hpl`) e executado pelos runners **Beam Direct** e **Spark**, trocando apenas a *Pipeline Run Configuration*, conforme a Aula 04 (Runtimes Avançados). O Hop traduz o `.hpl` para um pipeline Beam em tempo de execução (no log: `Created Apache Beam pipeline with name 'engajamento-beam'`). Por isso não há um `pipeline.py` escrito com o SDK Python do Beam.

---

## 1. Recorte de dados utilizado

| Item | Valor |
|---|---|
| Origem | `silver.interacoes_usuarios` (camada Silver no PostgreSQL) |
| Volume | **1.000 linhas**, 9 colunas |
| Colunas | `usuario_id`, `conteudo_id`, `tipo_interacao`, `data_hora`, `tempo_consumido`, `percentual_conclusao`, `avaliacao_atribuida`, `data_hora_processamento`, `id_execucao` |
| Campos de auditoria preservados | `data_hora_processamento`, `id_execucao` |

O mesmo recorte foi usado em todas as comparações.

---

## 2. RF24 — Parquet × CSV

### 2.1 Pipelines

| Pipeline | Função |
|---|---|
| `exportar_interacoes.hpl` | lê a Silver e grava **o mesmo recorte** em CSV e em Parquet (a linha é copiada para os dois destinos) |
| `ler_csv.hpl` | lê o CSV e agrega por tipo de interação |
| `ler_parquet.hpl` | lê o Parquet e aplica **a mesma agregação** |

Agregação de referência (usada também no RF25): por `tipo_interacao` → quantidade de interações, tempo consumido total e percentual de conclusão médio.

### 2.2 Tamanho em disco

| Formato | Arquivo | Tamanho |
|---|---|---|
| CSV (UTF-8, com cabeçalho) | `dados/silver/csv/interacoes_usuarios.csv` | **107.770 bytes** |
| Parquet (compressão Snappy) | `dados/silver/parquet/interacoes_usuarios.snappy.parquet` | **19.334 bytes** |

**O Parquet ficou 5,6× menor.** Motivo: o Parquet armazena os dados por coluna e usa codificação por dicionário. Colunas com muita repetição viram códigos curtos:

- `id_execucao`: o mesmo UUID de 36 caracteres nas 1.000 linhas;
- `data_hora_processamento`: o mesmo valor nas 1.000 linhas;
- `tipo_interacao`: apenas 6 valores distintos.

No CSV, cada um desses valores é escrito por extenso em todas as linhas.

### 2.3 Tempo de leitura + agregação (motor local do Hop)

| Execução | CSV | Parquet |
|---|---|---|
| 1ª | 0,246 s | 0,352 s |
| 2ª | 0,196 s | 0,251 s |
| 3ª | 0,169 s | 0,235 s |
| **Mediana** | **0,196 s** | **0,251 s** |

**Neste volume, o CSV foi ~0,05 s mais rápido.** Com 1.000 linhas, o tempo medido é quase todo custo fixo: iniciar as transformações e abrir o arquivo. O Parquet tem um custo fixo maior (inicializa a camada Hadoop, lê o rodapé com o esquema e descompacta o Snappy). A primeira execução do Parquet foi a mais lenta porque o Java ainda carregava as classes do Hadoop.

### 2.4 Esquema e tipos

O Parquet foi gravado com os tipos originais (inteiros, data/hora e decimal), sem conversão para texto, e a leitura recuperou os mesmos valores: as duas agregações produziram os mesmos 6 grupos, somando 1.000 interações. O CSV precisa que os tipos sejam declarados novamente na leitura (máscara de data, separador decimal).

### 2.5 Estratégia de particionamento (escolhida e justificada, não implementada)

- **Estratégia escolhida:** particionar por **mês da interação** (`ano_mes`), no padrão Hive, com uma pasta por partição:
  ```
  dados/silver/parquet/interacoes/ano_mes=2026-01/…parquet
  dados/silver/parquet/interacoes/ano_mes=2026-02/…parquet
  …
  ```
- **Justificativa:**
  - as análises do projeto são temporais: a Gold (`vw_kpi_engajamento_mensal`) e o dashboard filtram por período, então uma consulta de um mês leria apenas a pasta daquele mês (*partition pruning*);
  - o padrão `coluna=valor` é reconhecido por Spark, Beam e pelas ferramentas de consulta.
- **Alternativas descartadas:** por dia ou por usuário gerariam centenas de arquivos minúsculos (o problema dos *small files*: mais tempo abrindo arquivos do que lendo dados).
- **Por que não foi implementada:** com 1.000 linhas, as 8 partições mensais teriam de 100 a 150 linhas cada, arquivos de poucos KB. Neste volume, o particionamento pioraria a leitura. Ele passa a compensar quando cada partição tem ao menos dezenas de MB.

### 2.6 Conclusão do RF24

Neste volume, o Parquet vale pelo **armazenamento** (5,6× menor) e pelo **esquema embutido** (tipos preservados), e não pelo tempo de leitura. O ganho de leitura aparece quando o volume é grande o bastante para o custo fixo ficar desprezível (milhões de linhas) e quando a consulta lê poucas colunas, que é onde o formato colunar se destaca.

---

## 3. RF25 — Apache Beam: Direct Runner e Spark

### 3.1 Pipeline

`engajamento_beam.hpl`: **o mesmo arquivo `.hpl` foi executado nos três runtimes**, trocando apenas a *Pipeline Run Configuration*.

```
Gerar 1 linha → Caminho do parquet → Ler Parquet → Agregar por tipo → Gravar resultado
(Row Generator)  (Get Variables)     (Parquet In)   (Memory Group By)  (Parquet Out)
```

- **Entrada:** Parquet da Silver (`interacoes_usuarios.snappy.parquet`, 1.000 linhas).
- **Regra de negócio:** engajamento por tipo de interação (quantidade, tempo total e percentual médio).
- **Saída:** Parquet em `dados/gold/beam/<runtime>/`. O parâmetro `RUNTIME` define a pasta.
- O Row Generator é necessário porque um pipeline Beam precisa começar num transform que o Beam aceite como origem. No console, o Beam converteu o Row Generator e o Memory Group By em operações nativas (`ROW GENERATOR`, `Group By`) e os demais em transformações genéricas.

### 3.2 Configurações de execução

| Nome | Engine type | Configuração |
|---|---|---|
| `local` | Hop local pipeline engine | padrão |
| `beam-direct` | Beam Direct pipeline engine | Number of workers = 1 |
| `spark-local` | Beam Spark pipeline engine | Spark master = `local[*]` (Spark embutido, todos os núcleos da máquina) |

Execução pelo terminal:
```powershell
C:\hop\hop-run.bat -j desafio_dados_2 -e dev -f "$PWD\hop\pipelines\engajamento_beam.hpl" -r <runtime> -p RUNTIME=<runtime> -l Basic
```

### 3.3 Medições (tempo total medido com `Measure-Command`, incluindo a inicialização do Java)

| Runtime | Código de saída | Tempo total | Arquivos gerados | Volume |
|---|---|---|---|---|
| local | 0 | **7,7 s** (pipeline: 2,07 s) | 1 | 1.000 linhas lidas → 6 grupos |
| beam-direct | 0 | **13,5 s** | 6 (um por *bundle*) | 1.000 linhas lidas → 6 grupos |
| spark-local | 0 | **66,0 s** | 4 (um por tarefa do Spark) | 1.000 linhas lidas → 6 grupos |

Uma primeira rodada deu 7,4 s, 12,7 s e 69,9 s, confirmando que as medições são estáveis.

No Beam e no Spark, cada *worker* grava o próprio arquivo, então a saída vem fatiada em vários arquivos. É o comportamento esperado do processamento distribuído.

### 3.4 Mesma regra de negócio nos três runtimes

O pipeline `comparar_runtimes.hpl` lê todas as saídas, identifica o runtime pela pasta e grava a comparação em `beam/evidencias/comparacao_runtimes.csv`:

| tipo_interacao | qtd_interacoes | tempo_consumido_total | percentual_conclusao_medio | local | beam-direct | spark-local |
|---|---|---|---|---|---|---|
| avaliação | 89 | 14.265 | 76,26 | ✅ | ✅ | ✅ |
| compartilhamento | 90 | 19.755 | 64,08 | ✅ | ✅ | ✅ |
| conclusão | 154 | 30.970 | 100,00 | ✅ | ✅ | ✅ |
| curtida | 129 | 32.302 | 68,87 | ✅ | ✅ | ✅ |
| início | 187 | 4.047 | 8,43 | ✅ | ✅ | ✅ |
| visualização | 351 | 43.542 | 45,69 | ✅ | ✅ | ✅ |
| **Total** | **1.000** | | | | | |

**Os três runtimes produziram exatamente o mesmo resultado**: 18 linhas (6 tipos × 3 runtimes), com valores idênticos.

### 3.5 Análise crítica

- Com 1.000 linhas, o **Beam Direct** levou ~1,8× e o **Spark local** ~8,6× o tempo do motor local do Hop.
- A diferença é quase toda **custo fixo de inicialização**:
  - no Beam, montar o grafo do pipeline leva cerca de 5 s (`Created Apache Beam pipeline` aparece 5 s após o início);
  - no Spark, somam-se a criação do `SparkContext`, a subida dos executores e a serialização e distribuição das tarefas, cerca de 60 s.
  O processamento das 1.000 linhas em si leva milissegundos em qualquer runtime.
- **Quando o Spark passaria a valer:** quando o volume não couber na memória de uma máquina, ou quando o tempo de processamento for muito maior que esses ~60 s de inicialização, na faixa de dezenas de milhões de linhas e, principalmente, com um cluster de várias máquinas. Em `local[*]`, o Spark só divide o trabalho entre os núcleos do mesmo computador.
- **Para o volume deste projeto, o runtime local do Hop é a escolha correta.** O valor do Beam é poder levar o **mesmo pipeline**, sem redesenho, para Spark ou Flink quando o volume crescer, como foi demonstrado aqui.

---

## 4. Configuração do ambiente (Hop 2.19 no Windows)

A partir do Hop 2.19, o zip padrão não traz os plugins grandes. Foram necessários:

| Necessidade | Sintoma | Solução |
|---|---|---|
| Plugin de Parquet | `Can't run pipeline due to plugin missing` | `C:\hop\hop.bat marketplace install hop-tech-parquet` (ou pela perspectiva Marketplace) |
| Biblioteca do Hadoop para o Parquet | `NoClassDefFoundError: org/apache/hadoop/thirdparty/.../Interners` | copiar `hadoop-shaded-guava-1.3.0.jar` (Maven Central) para `C:\hop\lib\core` e reiniciar o Hop |
| Bug do Text File Output com colunas TEXT | `NegativeArraySizeException: -2147483648` | declarar os campos de saída com *Length* = -1 |
| Plugin do Beam | Engine type sem opções Beam | `C:\hop\hop.bat marketplace install hop-engines-beam` (≈ 391 MB) e reiniciar o Hop |
| Hadoop no Windows (Spark) | `HADOOP_HOME and hadoop.home.dir are unset` | `winutils.exe` e `hadoop.dll` (build Hadoop 3.3.6) em `C:\hadoop\bin` + `-Dhadoop.home.dir=C:\hadoop` |
| Conflito da interface web do Spark | `ServletContainer is not a javax.servlet.Servlet` | desligar a Spark UI com `-Dspark.ui.enabled=false` |

As duas opções Java ficam na variável de ambiente usada pelos scripts do Hop:
```powershell
[Environment]::SetEnvironmentVariable("HOP_OPTIONS", "-Xmx2048m -Dspark.ui.enabled=false -Dhadoop.home.dir=C:\hadoop", "User")
```
Terminais e o Hop GUI precisam ser reabertos para enxergar a variável (o terminal integrado do VS Code só a enxerga depois de reiniciar o VS Code).

---

## 5. Evidências

| Evidência | Local |
|---|---|
| Pipelines | `hop/pipelines/exportar_interacoes.hpl`, `ler_csv.hpl`, `ler_parquet.hpl`, `engajamento_beam.hpl`, `comparar_runtimes.hpl` |
| Configurações de execução | `metadata/pipeline-run-configuration/` (`local`, `beam-direct`, `spark-local`) |
| Comparação entre runtimes | `beam/evidencias/comparacao_runtimes.csv` |
| Este registro de medições | `beam/evidencias/README.md` |
| Arquivos gerados (não versionados, reproduzíveis) | `dados/silver/csv/`, `dados/silver/parquet/`, `dados/gold/beam/<runtime>/` |
