# Imagem leve com o CLI "metadata" do OpenMetadata (conector PostgreSQL).
# Substitui o container Airflow do compose oficial: a ingestao roda sob
# demanda e o container e removido ao terminar (docker compose run --rm).
FROM python:3.11-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libpq-dev \
 && rm -rf /var/lib/apt/lists/*

# A versao do pacote acompanha a versao do servidor (1.13.6)
RUN pip install --no-cache-dir "openmetadata-ingestion[postgres]==1.13.6.3"

WORKDIR /config
