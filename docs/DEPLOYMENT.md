# City OS — Deployment

The demo runs on **vps02** as a Docker Compose stack (`Dockerfile`, `compose.yaml`).
It replaced the earlier Dokploy setup (Docker Swarm, Traefik, Railpack builds and an
external registry), removed in November 2026.

## Services

| Service | Image | Notes |
|---|---|---|
| `frontend` | `Dockerfile` target `frontend` | SvelteKit on Bun (`svelte-adapter-bun`); `PUBLIC_API_URL` is baked in at build time |
| `backend` | target `backend` | Elysia API compiled to one executable (`bun build --compile`) |
| `migrate` | target `migrate` | one-shot `drizzle-kit migrate`; the backend starts only after it succeeds |
| `postgres` | `postgres:18.6` | database `CityOs`, volume `postgres-data` |
| `redis` | `redis:8.8.4-alpine` | Better Auth secondary storage |
| `rustfs` | `rustfs/rustfs:1.0.4` | S3-compatible storage for uploads, volume `rustfs-data` |

## Networking

Only `frontend`, `backend` and `rustfs` publish ports, and only on vps02's NetBird
address. Caddy on vps03 (the public edge, TLS and WAF) serves:

| Name | Goes to |
|---|---|
| `city-os.demo.yob-yob.com` | frontend |
| `api.city-os.demo.yob-yob.com` | backend |
| `rustfs-city-os.demo.yob-yob.com` | rustfs S3 API (browsers upload/download with presigned URLs); console under `/rustfs`, reachable from the NetBird mesh only |

## Deploys

A push to `main` runs `.github/workflows/deploy.yml`, which SSHes to vps02 with a key
that can only run `deploy-project city-os`. That script checks the commit is on `main`,
checks it out in `/root/projects/city-os` and runs
`docker compose up --detach --build --remove-orphans --wait`.

## Settings

The `.env` next to `compose.yaml` on the server is written by Ansible from the
infrastructure repo's vault (`ansible/playbooks/vps02-projects.yml`) and is never
committed. The backend and the migration read it whole (`env_file`); the other services
only get the variables `compose.yaml` passes them.
