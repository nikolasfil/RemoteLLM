# syntax=docker/dockerfile:1.7

FROM python:3.12.8-slim-bookworm AS build
ARG LITELLM_VERSION=1.80.5
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefix=/opt/litellm --no-compile "litellm[proxy]==${LITELLM_VERSION}" "langfuse<4" socksio prisma
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends libatomic1
RUN PYTHONPATH="/opt/litellm/lib/python3.12/site-packages" \
    PATH="/opt/litellm/bin:${PATH}" \
    /opt/litellm/bin/prisma generate \
    --schema=/opt/litellm/lib/python3.12/site-packages/litellm/proxy/schema.prisma

FROM python:3.12.8-slim-bookworm AS runtime
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends libatomic1
ENV PATH="/opt/litellm/bin:${PATH}" \
    PYTHONPATH="/opt/litellm/lib/python3.12/site-packages"
COPY --from=build /opt/litellm /opt/litellm
COPY --from=build /root/.cache/prisma-python /root/.cache/prisma-python
WORKDIR /app
EXPOSE 4000
