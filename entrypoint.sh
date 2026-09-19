#!/usr/bin/env sh
set -e

# MLflow's server uses Flask login sessions when auth is on, so it needs a secret key.
# Prefer the one you set in Railway; generate a fallback so the server always boots.
: "${MLFLOW_FLASK_SERVER_SECRET_KEY:=$(python -c 'import secrets;print(secrets.token_hex(32))')}"
export MLFLOW_FLASK_SERVER_SECRET_KEY

# SQLAlchemy 2.x rejects the legacy postgres:// scheme; normalize to postgresql://.
# (Tracking store only — Postgres is solid for that.)
BACKEND_STORE_URI="$(printf '%s' "$BACKEND_STORE_URI" | sed 's|^postgres://|postgresql://|')"

# Auth store: use SQLite (the well-tested default for MLflow's experimental basic-auth).
# Postgres for the *auth* store is the boot-crash suspect; the tracking store stays on
# Postgres. Set AUTH_DB_PATH to a file on a mounted Railway volume if you want the user
# list (you + Alex) to survive redeploys; otherwise it resets and you re-add users.
AUTH_DB_PATH="${AUTH_DB_PATH:-/app/mlflow_auth.db}"

cat > /app/basic_auth.ini <<EOF
[mlflow]
default_permission = READ
database_uri = sqlite:///${AUTH_DB_PATH}
admin_username = ${MLFLOW_ADMIN_USERNAME:-admin}
admin_password = ${MLFLOW_ADMIN_PASSWORD:-changeme}
authorization_function = mlflow.server.auth:authenticate_request_basic_auth
EOF

export MLFLOW_AUTH_CONFIG_PATH=/app/basic_auth.ini

# --capture-output: surface the worker's real traceback in the logs (gunicorn hides it
#   by default, which is why you've only seen "worker failed to boot").
# --workers 1: fine for a two-person server; avoids first-boot migration races.
exec mlflow server \
  --host 0.0.0.0 \
  --port "${PORT:-8080}" \
  --workers 1 \
  --backend-store-uri "${BACKEND_STORE_URI}" \
  --artifacts-destination "${ARTIFACT_ROOT}" \
  --serve-artifacts \
  --app-name basic-auth \
  --gunicorn-opts "--capture-output --log-level debug"
