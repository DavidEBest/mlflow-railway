# MLflow on Railway (Cloudflare R2 artifacts, basic auth)

A self-hosted MLflow tracking server for Railway. Postgres for run metadata, R2 for
artifacts (rerun files + videos), basic auth so you and Alex each get a login. Artifacts
are **proxied through the server**, so only the server holds R2 credentials — clients just
need the URL and a login. $0 beyond your existing Railway + R2.

## Deploy

1. **Push this repo to your GitHub** (a new private repo is fine).
2. In Railway: **New Project → Deploy from GitHub repo →** pick this repo. Railway sees the
   `Dockerfile` and builds it. (Nothing to paste — Railway builds Dockerfiles from the repo.)
3. **Add Postgres:** in the same project, **New → Database → PostgreSQL.**
4. **Set the service Variables** (your MLflow service → Variables). See `.env.example`; the
   essentials:
   - `BACKEND_STORE_URI=${{Postgres.DATABASE_URL}}` (reference the Postgres plugin)
   - `ARTIFACT_ROOT=s3://<your-r2-bucket>/artifacts`
   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (an R2 token with Object Read & Write)
   - `AWS_DEFAULT_REGION=auto`
   - `MLFLOW_S3_ENDPOINT_URL=https://<accountid>.r2.cloudflarestorage.com`
   - `MLFLOW_ADMIN_USERNAME` and `MLFLOW_ADMIN_PASSWORD` (**change the password**)
5. Railway builds and deploys. Open the generated URL — you'll get a login prompt. Sign in
   with your admin username/password.

> If the Postgres URL Railway gives you starts with `postgres://`, change it to `postgresql://`.

## Give Alex a login

After it's up, create his user via the REST API (uses your admin creds):

```bash
curl -u "$ADMIN_USER:$ADMIN_PASS" \
  -X POST "https://<your-app>.up.railway.app/api/2.0/mlflow/users/create" \
  -H "Content-Type: application/json" \
  -d '{"username": "alex", "password": "<a-password>"}'
```

## Point clients at it (the agent, you, Alex)

Set these three — and **no R2 credentials** (artifacts are proxied):

```
MLFLOW_TRACKING_URI=https://<your-app>.up.railway.app
MLFLOW_TRACKING_USERNAME=<user>
MLFLOW_TRACKING_PASSWORD=<pass>
```

`record_experiment.py` / `verify_experiment.py` read these from the environment.

## Smoke test (confirms the R2 round-trip)

With the three client vars set:

```python
import mlflow
mlflow.set_experiment("smoke-test")
with mlflow.start_run():
    mlflow.log_param("hello", "world")
    mlflow.log_metric("ok", 1)
    open("/tmp/t.txt", "w").write("hi")
    mlflow.log_artifact("/tmp/t.txt")
print("logged — check the run + that the artifact opens in the UI")
```

If the run shows up and the artifact opens in the MLflow UI, metadata (Postgres) and
artifacts (R2, via the proxy) are both working.

## Notes

- Auth users live in Postgres (via the generated `basic_auth.ini`), so they survive redeploys.
- R2 has no egress fees — good for re-watching videos.
- Let Railway back up the Postgres DB; it's your entire run history.
