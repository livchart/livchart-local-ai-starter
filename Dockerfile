# syntax=docker/dockerfile:1.7
FROM ubuntu:24.04

ARG LIVCHART_DOWNLOAD_URL=https://github.com/livchart/livchart/releases/latest/download/LivChart_Linux_Dist.zip

ENV LIVCHART_HOME=/opt/livchart \
    DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUTF8=1 \
    PYTHONIOENCODING=utf-8 \
    LIVCHART_ENV=production \
    LIVCHART_LOG_LEVEL=INFO \
    LIVCHART_CONSOLE_LOG_ENABLED=1 \
    PORT=5000

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        iproute2 \
        libnss3 \
        python3 \
        unixodbc \
        unzip \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/livchart

RUN --mount=type=cache,target=/tmp/livchart-download \
    set -eu; \
    download="/tmp/livchart-download/LivChart_Linux_Dist.zip"; \
    if [ -s "$download" ] && unzip -tq "$download" >/dev/null 2>&1; then \
        echo "Using cached LivChart package"; \
    else \
    for attempt in 1 2 3 4 5 6 7 8; do \
        curl -fL --http1.1 \
            --connect-timeout 30 \
            --speed-limit 1024 \
            --speed-time 30 \
            --continue-at - \
            -o "$download" \
            "${LIVCHART_DOWNLOAD_URL}" && break; \
        status="$?"; \
        if [ "$status" = "22" ] || [ "$attempt" = "8" ]; then exit "$status"; fi; \
        sleep 5; \
    done; \
    fi \
    && cp "$download" /tmp/LivChart_Linux_Dist.zip \
    && unzip -q /tmp/LivChart_Linux_Dist.zip -d /opt/livchart \
    && rm -f /tmp/LivChart_Linux_Dist.zip \
    && chmod +x /opt/livchart/bin/LivChart \
    && mkdir -p /opt/livchart/config /opt/livchart/logs /opt/livchart/DataSet

RUN rm -rf /opt/livchart/license.key /opt/livchart/activation.dat \
    && touch /opt/livchart/license.key /opt/livchart/activation.dat

COPY starter-config/ /opt/livchart/defaults/
COPY starter-config/ /opt/livchart/config/
COPY starter-data/DataSet/ /opt/livchart/starter-data/DataSet/

COPY scripts/livchart-entrypoint.sh /usr/local/bin/livchart-entrypoint
RUN chmod +x /usr/local/bin/livchart-entrypoint

EXPOSE 5000

ENTRYPOINT ["livchart-entrypoint"]
CMD ["./bin/LivChart"]
