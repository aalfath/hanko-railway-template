# Hanko on Railway: the official Hanko API image plus a small wrapper.
# The upstream image is distroless (no shell), so a static BusyBox shell runs
# start.sh, and Caddy serves the demo page and proxies the public API.
FROM busybox:1.37.0-musl@sha256:f6a95d611e0a8780fabdb2aec43e31275b2720dfefa3e41b16835bfc42454478 AS busybox
FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM ghcr.io/teamhanko/hanko:v3.1.0@sha256:80ea5d67937cb3674bdde157365c57ff04420d5337f1277232d47e858613b19c

USER root
COPY --from=busybox /bin/busybox /bin/busybox
RUN ["/bin/busybox", "--install", "-s", "/bin"]
COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY Caddyfile start.sh /app/
COPY demo /app/demo
USER 65532:65532

ENV PORT=8080 \
    HOME=/tmp \
    XDG_CONFIG_HOME=/tmp/caddy-config \
    XDG_DATA_HOME=/tmp/caddy-data
EXPOSE 8080 8001

ENTRYPOINT ["/bin/sh", "/app/start.sh"]
