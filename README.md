# Deploy to Control Plane add-in (`cpln-deploy`)

An Effortless **add-in seed** (kind `child`), mounted at `deploy/`. Requires
the `rulebook-backend` add-in (mounted at `backend/`). It has no rulebook of
its own and no hand-written deploy files: its one build step,
`create-deployment-pipeline`, reads the project's
`../../effortless-rulebook/effortless-rulebook.json` and your answers and
generates `deploy/pipeline/`.

## What the build produces (`deploy/pipeline/`)

| File | What it is |
|---|---|
| `Dockerfile` | `node:20-alpine` image of `backend/api/` (the API rulebook-to-node-postgres-api generates), port 42441 |
| `docker-entry.mjs` | Maps `DATABASE_URL` onto the `PG*` variables the API reads, then starts it |
| `access.yaml` | Identity `<workloadName>-identity` and a policy letting it reveal the secret `<workloadName>-database-url` |
| `workload.yaml` | The cpln workload: public inbound, `DATABASE_URL` = `cpln://secret/<workloadName>-database-url` (a reference, never a value) |
| `deploy.sh` | Builds + pushes the image, applies `access.yaml` then `workload.yaml` |

## Deploying

`effortless build` does **not** run `deploy.sh`. Build the backend, then run it:

```bash
cd backend && effortless build && cd ..
cd deploy && effortless build && cd ..
DATABASE_URL=postgres://user:password@host:5432/database bash deploy/pipeline/deploy.sh   # first time
bash deploy/pipeline/deploy.sh                                                             # afterwards
```

- The cpln token comes from env `SEED_SECRET_cplnToken`, else key `cplnToken`
  in `deploy/seed-secret-values.json`
  (`{"replacements":[{"key":"cplnToken","value":"..."}]}`). It is exported as
  `CPLN_TOKEN` for the cpln CLI and never printed.
- When `DATABASE_URL` is set, `deploy.sh` writes it to the cpln secret
  `<workloadName>-database-url` (on stdin, never echoed); otherwise that secret
  must already exist. Point it at the database `backend/postgres/init-db.sh`
  set up.

Needs the `cpln` CLI, Docker and Node. `API_DIR` overrides where the API is.

## Questions

| Key | Default | Used for |
|---|---|---|
| `cplnOrg` | (required) | The org the image and workload live in |
| `cplnGvc` | (required, discovered from the org) | The GVC the workload is applied to |
| `workloadName` | `my-rulebook-api` | Workload and image name; also names the identity, policy and database secret |
| `cplnToken` | (required, secret, persisted) | Kept in `seed-secret-values.json` / your account's secret store; never committed (`.gitignore`) |
