# City OS — Deployment

City OS runs in its own LXC on **homelab01** (Proxmox at home) as a Docker Compose stack
(`Dockerfile`, `compose.yaml`). It moved there from vps02 in November 2026; before that it
ran on Dokploy (Docker Swarm, Traefik, Railpack builds and an external registry).

## Services

| Service | Image | Notes |
|---|---|---|
| `frontend` | `Dockerfile` target `frontend` | SvelteKit on Bun (`svelte-adapter-bun`); `PUBLIC_API_URL` is baked in at build time |
| `backend` | target `backend` | Elysia API compiled to one executable (`bun build --compile`) |
| `migrate` | target `migrate` | one-shot `drizzle-kit migrate`; the backend starts only after it succeeds |
| `postgres` | `postgres:18.6` | database `CityOs`, volume `postgres-data` |
| `redis` | `redis:8.8.4-alpine` | Better Auth secondary storage |

Uploads go to the shared S3 at `https://s3.yob-yob.com` (RustFS on vps02), with a key that
can only use this app's buckets (`asset-tracking`, `city-os`).

## Networking

Only `frontend` and `backend` publish ports, and only on the LXC's LAN address. Caddy on
vps03 (the public edge: TLS and WAF) proxies to them over the NetBird route:

| Name | Goes to |
|---|---|
| `city-os.yob-yob.com` | frontend |
| `api.city-os.yob-yob.com` | backend |
| `city-os.demo.yob-yob.com`, `api.city-os.demo.yob-yob.com` | redirect to the names above |

## Deploys

A push to `main` runs `.github/workflows/deploy.yml`. It SSHes to the LXC through vps03
(the LXC has no public address) with one key that, on vps03, can only open a tunnel to the
LXC and, on the LXC, can only run `deploy-project city-os`. That script checks the commit is
on `main`, checks it out in `/root/projects/city-os` and runs
`docker compose up --detach --build --remove-orphans --wait`.

## Settings

The `.env` next to `compose.yaml` on the LXC is written by Ansible from the infrastructure
repo's vault (`ansible/playbooks/homelab-apps.yml`) and is never committed. The backend and
the migration read it whole (`env_file`); the other services only get the variables
`compose.yaml` passes them.
