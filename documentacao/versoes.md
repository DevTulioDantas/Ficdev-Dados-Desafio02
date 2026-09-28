# Versões das ferramentas (RF15)

Saída real dos comandos na máquina de cada integrante.
Libia: 27/09/2026 · Túlio: 28/09/2026.

| Ferramenta | Libia | Túlio | Como conferir |
|---|---|---|---|
| Java | 17.0.18 (sistema) · Hop usa JDK 21.0.12 via `HOP_JAVA_HOME` (Hop 2.19 exige Java 21) | OpenJDK 21.0.12.1 LTS | `java -version` |
| Python | 3.12.10 | 3.14.6 | `python --version` |
| Docker | 29.7.2, build a7dcaa6 | 29.7.2, build a7dcaa6 | `docker --version` |
| Apache Hop | 2.19.0 | 2.19.0 | Hop GUI → Help → About |
| PostgreSQL (pgvector) | 16.15 (Debian 16.15-1.pgdg12+2) (pgvector/pgvector:pg16) | 16.15 (Debian 16.15-1.pgdg12+2) · extensão `vector` 0.8.6 (pgvector/pgvector:pg16) | `docker exec desafio-postgres psql -V` |
| MongoDB | | | `docker exec desafio-mongo mongosh --eval "db.version()"` |
| Apache Beam | | 2.74.0 (SDK Java, via plugin `hop-engines-beam` do Hop) | jar `beam-sdks-java-core-*.jar` em `C:\hop\plugins` |
| Runtime Spark | | Spark 3.5.8 (Scala 2.12), local, pelo Beam Spark runner (`beam-runners-spark-3` 2.74.0) · Hadoop winutils 3.3.6 no Windows | jars `spark-core_*.jar` e `beam-runners-spark-*.jar` em `C:\hop\plugins` |
| Parquet | | parquet-hadoop 1.17.1 (plugin `hop-tech-parquet`) | jar `parquet-hadoop-*.jar` em `C:\hop\plugins` |
| Apache Superset | | 6.1.0 (Docker) | Superset → Settings → About |
| OpenMetadata | 1.13.6 (servidor, Docker) · openmetadata-ingestion 1.13.6.3 | 1.13.6 (servidor, Docker) · openmetadata-ingestion 1.13.6.3 · Elasticsearch 9.3.0 | Rodapé da interface web · `docker ps --format "{{.Image}}"` |

## Observações

- **Beam não usa o SDK Python:** o processamento do RF25 roda dentro do Apache Hop
  (plugin `hop-engines-beam`, SDK Java). O mesmo `engajamento_beam.hpl` executa
  nas run configurations `local`, `beam-direct` e `spark-local`.
- **Spark no Windows** precisa de `winutils.exe` e `hadoop.dll` em `C:\hadoop\bin` e de
  `HOP_OPTIONS="-Xmx2048m -Dspark.ui.enabled=false -Dhadoop.home.dir=C:\hadoop"`.
- **Plugins do Hop 2.19** (cliente enxuto) são instalados pelo Marketplace:
  `hop.bat marketplace install hop-engines-beam` e `hop-tech-parquet`
  (o Parquet também precisa de `hadoop-shaded-guava-1.3.0.jar` em `C:\hop\lib\core`).
