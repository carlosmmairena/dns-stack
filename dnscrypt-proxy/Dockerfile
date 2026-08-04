# ---- Stage 1: descarga y verificación ----
FROM alpine:3.20 AS fetcher

ARG DNSCRYPT_VERSION=2.1.18
# "arm64" para Raspberry Pi OS de 64 bits (Pi 4/5, default actual)
# "arm" si tu Pi OS es de 32 bits
ARG CPU_ARCH=arm64
ARG PLATFORM=linux

# Clave pública oficial de firma de releases:
# https://github.com/DNSCrypt/dnscrypt-proxy/wiki/Updates
ENV DNSCRYPT_PUBLIC_KEY="RWTk1xXqcTODeYttYMCMLo0YJHaFEHn7a3akqHlb/7QvIQXHVPxKbjB5"

RUN apk add --no-cache curl minisign tar

WORKDIR /build

RUN ASSET_URL="$(curl -sL "https://api.github.com/repos/DNSCrypt/dnscrypt-proxy/releases/tags/${DNSCRYPT_VERSION}" \
      | grep "browser_download_url.*${PLATFORM}_${CPU_ARCH}-${DNSCRYPT_VERSION}.tar.gz\"" \
      | cut -d '"' -f 4)" \
    && echo "Descargando: ${ASSET_URL}" \
    && curl -sL -o dnscrypt-proxy.tar.gz "${ASSET_URL}" \
    && curl -sL -o dnscrypt-proxy.tar.gz.minisig "${ASSET_URL}.minisig" \
    && minisign -Vm dnscrypt-proxy.tar.gz -P "${DNSCRYPT_PUBLIC_KEY}" \
    && tar xzf dnscrypt-proxy.tar.gz \
    && find . -name dnscrypt-proxy -type f -exec mv {} /build/dnscrypt-proxy \;

# ---- Stage 2: imagen final mínima ----
FROM alpine:3.20

RUN apk add --no-cache ca-certificates \
    && addgroup -S dnscrypt && adduser -S -G dnscrypt dnscrypt

COPY --from=fetcher /build/dnscrypt-proxy /usr/local/bin/dnscrypt-proxy
RUN chmod +x /usr/local/bin/dnscrypt-proxy

USER dnscrypt
WORKDIR /config

ENTRYPOINT ["/usr/local/bin/dnscrypt-proxy"]
CMD ["-config", "/config/dnscrypt-proxy.toml"]
