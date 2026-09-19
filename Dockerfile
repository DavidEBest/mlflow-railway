# MLflow tracking server for Railway.
# - Postgres backend store (run/param/metric metadata)
# - Cloudflare R2 artifact store, proxied through the server (--serve-artifacts),
#   so clients never need R2 credentials
# - Basic auth, with the user list stored in Postgres (survives redeploys)
FROM python:3.12-slim

WORKDIR /app

# mlflow<3 keeps the basic-auth + serve-artifacts flags used here stable;
# psycopg2-binary = Postgres driver, boto3 = S3/R2 client.
RUN pip install --no-cache-dir "mlflow<3" mlflow[auth] psycopg2-binary boto3

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]
