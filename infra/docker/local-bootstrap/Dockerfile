FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY data-pipeline /src/data-pipeline
RUN pip install --no-cache-dir /src/data-pipeline

WORKDIR /app
COPY scripts/migrate-legacy-market-data.py scripts/restore-raw-market-data.py scripts/verify-fixed-market-data.py /app/scripts/
COPY config/fixed-market-data-baseline.json /app/config/fixed-market-data-baseline.json
COPY infra/docker/local-bootstrap/bootstrap.py /app/bootstrap.py

ENV PYTHONPATH=/src/data-pipeline
ENTRYPOINT ["python", "/app/bootstrap.py"]
