# syntax=docker/dockerfile:1.7

FROM alpine:3.21 AS builder
ARG MICROSOCKS_REF=master
RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache build-base git
RUN git clone --depth 1 --branch "${MICROSOCKS_REF}" https://github.com/rofl0r/microsocks.git /src
WORKDIR /src
RUN make

FROM alpine:3.21
RUN --mount=type=cache,target=/var/cache/apk \
    apk add --no-cache socat
COPY --from=builder /src/microsocks /usr/local/bin/microsocks
EXPOSE 1080 11434
USER 65534:65534
ENTRYPOINT ["sh", "-c", "socat TCP-LISTEN:${OLLAMA_FORWARD_PORT:-11434},fork,reuseaddr TCP:${OLLAMA_FORWARD_TARGET:-10.5.5.5:11434} & exec microsocks -i 0.0.0.0 -p 1080"]
