# syntax=docker/dockerfile:1
#
# City OS images, one Dockerfile with a target per service (see compose.yaml).
# Built on vps02 by `docker compose up --build`; deployed by .github/workflows/deploy.yml.

# ---- workspace with all dependencies (shared by every target) ----
FROM oven/bun:1.3.14 AS deps
WORKDIR /app
COPY . .
RUN bun install --frozen-lockfile

# ---- database migrations (drizzle-kit, run once per deploy before the backend) ----
FROM deps AS migrate
WORKDIR /app/packages/database
CMD ["bunx", "drizzle-kit", "migrate", "--config", "./drizzle.config.ts"]

# ---- backend: compiled to a single executable ----
FROM deps AS backend-build
RUN bun run --cwd apps/backend build

FROM oven/bun:1.3.14-slim AS backend
WORKDIR /app
COPY --from=backend-build /app/apps/backend/dist/backend_server ./backend_server
EXPOSE 3000
CMD ["./backend_server"]

# ---- frontend: SvelteKit (svelte-adapter-bun). The API URL is baked in at build time ----
FROM deps AS frontend
ARG PUBLIC_API_URL
ENV PUBLIC_API_URL=${PUBLIC_API_URL} \
    VITE_PUBLIC_API_URL=${PUBLIC_API_URL}
RUN bun run --cwd apps/frontend build
WORKDIR /app/apps/frontend
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
CMD ["bun", "build/index.js"]
