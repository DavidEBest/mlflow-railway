#!/usr/bin/env sh
set -e

# MLflow's server uses Flask login sessions when auth is on, so it needs a secret key.
# Prefer the one you set in Railway; generate a fallback so the server always boots.
# (Setting it explicitly in Railway keeps sessions stable across redeploys.)
: "${MLFLOW_FLASK_SERVER_SECRET_KEY:=$(python -c 'import secrets;print(secrets.token_hex(32))')}"
export MLFLOW_FLASK_SERVER_SECRET_KEY

# SQLAlchemy 2.x rejects the legacy postgres:// scheme; normalize to postgresql://.
normalize() { printf '%s' "$1" | sed 's|^postgres://|postgresql://|'; }
BACKEND_STORE_URI="$(normalize "$BACKEND_STORE_URI")"
AUTH_URI="$(normalize "${AUTH_DATABASE_URI:-$BACKEND_STORE_URI}")"

# Generate the basic-auth config at boot from env vars. Keeps the admin password out
# of the repo, and stores the user list in Postgres so logins survive redeploys.
cat > /app/basic_auth.ini <<EOF
[mlflow]
default_permission = READ
database_uri = ${AUTH_URI}
admin_username = ${MLFLOW_ADMIN_USERNAME:-admin}
admin_password = ${MLFLOW_ADMIN_PASSWORD:-changeme}
authorization_function = mlflow.server.auth:authenticate_request_basic_auth
EOF

export MLFLOW_AUTH_CONFIG_PATH=/app/basic_auth.ini

# --workers 1: avoids several gunicorn workers racing on the first-boot DB migration
# (that's the multi-worker churn you saw in the logs) and makes any real error legible.
# One worker is plenty for a two-person tracking server.
exec mlflow server \
  --host 0.0.0.0 \
  --port "${PORT:-8080}" \
  --workers 1 \
  --backend-store-uri "${BACKEND_STORE_URI}" \
  --artifacts-destination "${ARTIFACT_ROOT}" \
  --serve-artifacts \
  --app-name basic-auth
