#!/usr/bin/env sh
set -e

# Generate the basic-auth config at boot from env vars. This keeps the admin
# password out of the repo, and points the auth user-list at Postgres so logins
# (yours + Alex's) survive redeploys instead of resetting.
cat > /app/basic_auth.ini <<EOF
[mlflow]
default_permission = READ
database_uri = ${AUTH_DATABASE_URI:-$BACKEND_STORE_URI}
admin_username = ${MLFLOW_ADMIN_USERNAME:-admin}
admin_password = ${MLFLOW_ADMIN_PASSWORD:-changeme}
authorization_function = mlflow.server.auth:authenticate_request_basic_auth
EOF

export MLFLOW_AUTH_CONFIG_PATH=/app/basic_auth.ini

# Railway injects $PORT. Artifacts are proxied to R2 via --serve-artifacts, so
# only this server needs AWS_*/MLFLOW_S3_ENDPOINT_URL — clients do not.
exec mlflow server \
  --host 0.0.0.0 \
  --port "${PORT:-8080}" \
  --backend-store-uri "${BACKEND_STORE_URI}" \
  --artifacts-destination "${ARTIFACT_ROOT}" \
  --serve-artifacts \
  --app-name basic-auth
