# syntax=docker/dockerfile:1.7
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG SEARXNG_UID=977
ARG SEARXNG_GID=977

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl tini gosu \
    python3 python3-venv python3-dev python-is-python3 \
    uwsgi uwsgi-plugin-python3 \
    git build-essential \
    libxslt1.1 libxslt-dev zlib1g zlib1g-dev libffi-dev libssl-dev vulkan-tools libvulkan1 mesa-vulkan-drivers \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd -g ${SEARXNG_GID} searxng \
 && useradd -u ${SEARXNG_UID} -g ${SEARXNG_GID} \
    -d /usr/local/searxng -s /usr/sbin/nologin -M searxng \
 && mkdir -p /usr/local/searxng

# use bash so we can rely on pipefail from here on
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG SEARXNG_REF=master
RUN set -euo pipefail \
 && git clone --depth=1 --branch "${SEARXNG_REF}" https://github.com/searxng/searxng /usr/local/searxng/searxng-src \
 && python3 -m venv /usr/local/searxng/venv \
 && source /usr/local/searxng/venv/bin/activate \
 && pip install --upgrade pip setuptools wheel \
 # Install Python runtime deps FIRST (prevents msgspec import error)
 && pip install --no-build-isolation -r /usr/local/searxng/searxng-src/requirements.txt \
                                  -r /usr/local/searxng/searxng-src/requirements-server.txt \
 # Now install SearXNG itself (non-editable)
 && pip install --no-build-isolation /usr/local/searxng/searxng-src

COPY docker/uwsgi.ini /usr/local/searxng/dockerfiles/uwsgi.ini
COPY docker/entrypoint.sh /usr/local/searxng/entrypoint.sh
COPY docker/exes/ /usr/local/bin/
COPY config/ /etc/searxng/

VOLUME ["/etc/searxng", "/var/cache/searxng"]

ENV CONFIG_PATH=/etc/searxng \
    SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml \
    UWSGI_SETTINGS_PATH=/etc/searxng/uwsgi.ini \
    DATA_PATH=/var/cache/searxng \
    BIND_ADDRESS=0.0.0.0:8080 \
    FORCE_OWNERSHIP=true

RUN mkdir -p /etc/searxng /var/cache/searxng /var/log/uwsgi \
 && chown -R searxng:searxng /usr/local/searxng /etc/searxng /var/cache/searxng /var/log/uwsgi \
 && chmod +x /usr/local/searxng/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/searxng/entrypoint.sh"]

