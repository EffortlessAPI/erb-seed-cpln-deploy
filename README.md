# Deploy to Control Plane add-in (`cpln-deploy`)

An Effortless **add-in seed** (kind `child`), mounted at `deploy/`. Requires
the `rulebook-backend` add-in (mounted at `backend/`). It generates nothing at
build time; it ships `deploy.sh` and a `Dockerfile`.

## What `deploy.sh` does

1. Reads the cpln token from env `SEED_SECRET_cplnToken`, else from
   `deploy/seed-secret-values.json` (`{"replacements":[{"key":"cplnToken","value":"..."}]}`).
   It is exported as `CPLN_TOKEN` for the cpln CLI and never printed.
2. Builds `backend/api/` (the generated Node API) with this folder's
   `Dockerfile` and pushes it to your org's registry
   (`cpln image build --push`), tagged with a UTC timestamp.
3. Applies a `standard` workload (port 42441, one replica, public) in your GVC
   (`cpln apply`). `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` and `PGDATABASE`
   are passed to the workload when they are set in your shell; point them at
   the database `backend/postgres/init-db.sh` set up.

`effortless build` does **not** run it. Run it yourself, after building the
backend:

```bash
cd backend && effortless build && cd ..
PGHOST=... PGDATABASE=... ./deploy/deploy.sh
```

Needs the `cpln` CLI, Docker and Node. `API_DIR` overrides where the API is.

## Questions

| Key | Default | Used for |
|---|---|---|
| `cplnOrg` | (required) | The org the image and workload live in |
| `cplnGvc` | (required, discovered from the org) | The GVC the workload is applied to |
| `workloadName` | `my-rulebook-api` | Workload and image name |
| `cplnToken` | (required, secret, persisted) | Kept in `seed-secret-values.json` / your account's secret store; never committed (`.gitignore`) |
