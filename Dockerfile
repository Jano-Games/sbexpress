FROM node:22-bookworm-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN corepack enable && corepack prepare pnpm@10.18.3 --activate
COPY . .
# Schema generation/build does not connect to a database. No live credentials enter this image.
RUN DATABASE_URL=postgresql://build:build@localhost/build pnpm install --frozen-lockfile
RUN pnpm build

FROM node:22-bookworm-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build --chown=node:node /app /app
ENV NODE_ENV=production SERVE_FRONTEND=true FRONTEND_DIST=/app/apps/frontend/dist
USER node
WORKDIR /app/apps/backend
CMD ["node", "dist/index.mjs"]
