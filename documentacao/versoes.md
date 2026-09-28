# Versões das ferramentas (RF15)

Preencher com a saída real de cada comando na máquina de cada integrante.
Valores já preenchidos: máquina da Libia (27/09/2026).

| Ferramenta | Versão | Como conferir |
|---|---|---|
| Java | 17.0.18 (sistema) · Hop usa JDK 21.0.12 via `HOP_JAVA_HOME` (Hop 2.19 exige Java 21) | `java -version` |
| Python | 3.12.10 | `python --version` |
| Docker | 29.7.2, build a7dcaa6 | `docker --version` |
| Apache Hop | 2.19.0 | Hop GUI → Help → About |
| PostgreSQL (pgvector) | 16.15 (Debian 16.15-1.pgdg12+2) (pgvector/pgvector:pg16) | `docker exec desafio-postgres psql -U postgres -c "select version();"` |
| MongoDB | | `docker exec desafio-mongo mongosh --eval "db.version()"` |
| Apache Beam (SDK Python) | | `pip show apache-beam` |
| Runtime Spark | | `spark-submit --version` ou imagem Docker usada |
| Apache Superset | | Superset → Settings → About |
| OpenMetadata | 1.13.6 (servidor, Docker) · openmetadata-ingestion 1.13.6.3 | Rodapé da interface web |
