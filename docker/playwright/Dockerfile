# syntax=docker/dockerfile:1.7

FROM mcr.microsoft.com/playwright:v1.48.2-noble

ARG PLAYWRIGHT_MCP_VERSION=0.0.75

RUN --mount=type=cache,target=/root/.npm \
    npm install -g "@playwright/mcp@${PLAYWRIGHT_MCP_VERSION}" \
    && npm cache clean --force

WORKDIR /workspace/projects

CMD ["npx", "@playwright/mcp@0.0.75", "--headless", "--host", "0.0.0.0"]
