# syntax=docker/dockerfile:1.7
# Builds llama-server from microsoft/BitNet source.
# Clang 18 is mandatory — GCC is not supported by BitNet.cpp.
#
# ARM64 note: if the container crashes at ggml-bitnet-mad.cpp line 811,
# add -DGGML_BITNET_ARM_TL1=OFF to the cmake command below to disable
# the NEON bitnet kernel and fall back to the generic path.

FROM ubuntu:24.04 AS build

ARG BITNET_REF=main
ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        clang-18 \
        cmake \
        ninja-build \
        make \
        git \
        ca-certificates \
        libcurl4-openssl-dev

WORKDIR /build

RUN git clone \
    --recurse-submodules \
    --depth 1 \
    --shallow-submodules \
    --branch "$BITNET_REF" \
    https://github.com/microsoft/BitNet.git .

RUN cmake -B build \
        -G Ninja \
        -DCMAKE_C_COMPILER=clang-18 \
        -DCMAKE_CXX_COMPILER=clang++-18 \
        -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --target llama-server -j"$(nproc)"


FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        libcurl4 \
        curl \
    && useradd -m -u 1000 bitnet

WORKDIR /app
COPY --from=build /build/build/bin/llama-server /app/llama-server
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/llama-server /app/entrypoint.sh

USER bitnet
EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]
