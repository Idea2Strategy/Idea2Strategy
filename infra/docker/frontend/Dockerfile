FROM node:22-alpine

RUN corepack enable \
    && corepack prepare pnpm@10.15.0 --activate

WORKDIR /workspace/ui

COPY ui/package.json ui/pnpm-lock.yaml ui/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY ui/ ./

EXPOSE 5173

CMD ["pnpm", "dev", "--host", "0.0.0.0", "--port", "5173"]
