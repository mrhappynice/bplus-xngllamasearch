#!/bin/sh
set -e

# Fail early on Windows CRLF files mounted by mistake
if [ "$(printf '%s' "$(head -c1 /usr/local/searxng/entrypoint.sh 2>/dev/null | od -An -t x1 | awk '{print $1}')" )" = "ef" ]; then
  echo "Refusing to run: CRLF detected in scripts. Use LF line endings." >&2
  exit 1
fi

CONFIG_PATH="${CONFIG_PATH:-/etc/searxng}"
SEARXNG_SETTINGS_PATH="${SEARXNG_SETTINGS_PATH:-${CONFIG_PATH}/settings.yml}"
UWSGI_SETTINGS_PATH="${UWSGI_SETTINGS_PATH:-${CONFIG_PATH}/uwsgi.ini}"
DATA_PATH="${DATA_PATH:-/var/cache/searxng}"
BIND_ADDRESS="${BIND_ADDRESS:-0.0.0.0:8080}"
FORCE_OWNERSHIP="${FORCE_OWNERSHIP:-true}"

# Create required dirs and enforce ownership if asked
mkdir -p "$CONFIG_PATH" "$DATA_PATH" /var/log/uwsgi
if [ "$FORCE_OWNERSHIP" = "true" ]; then
  chown -R searxng:searxng "$CONFIG_PATH" "$DATA_PATH" /var/log/uwsgi
fi

# Ship default uwsgi.ini if missing
if [ ! -f "$UWSGI_SETTINGS_PATH" ]; then
  echo "Create $UWSGI_SETTINGS_PATH"
  cp /usr/local/searxng/dockerfiles/uwsgi.ini "$UWSGI_SETTINGS_PATH"
  chown searxng:searxng "$UWSGI_SETTINGS_PATH"
fi

# If no settings.yml provided, generate a minimal one that defers to defaults;
# admins usually mount their own settings (matching official guidance). :contentReference[oaicite:6]{index=6}
if [ ! -f "$SEARXNG_SETTINGS_PATH" ]; then
  echo "Create $SEARXNG_SETTINGS_PATH"
  cat > "$SEARXNG_SETTINGS_PATH" <<'YML'
use_default_settings: true
general:
  instance_name: "SearXNG"
search:
  safe_search: 2
  autocomplete: "duckduckgo"
server:
  limiter: true
  image_proxy: true
YML
  chown searxng:searxng "$SEARXNG_SETTINGS_PATH"
fi

# Map legacy envs to SearXNG config via env expansion (official container honors env, too) :contentReference[oaicite:7]{index=7}
# These are read by SearXNG at runtime; no file editing required.
export SEARXNG_SETTINGS_PATH
[ -n "$BASE_URL" ] && export SEARXNG_BASE_URL="$BASE_URL"
[ -n "$INSTANCE_NAME" ] && export SEARXNG_INSTANCE_NAME="$INSTANCE_NAME"
[ -n "$AUTOCOMPLETE" ] && export SEARXNG_AUTOCOMPLETE="$AUTOCOMPLETE"
# Morty (result proxy), if you use it
[ -n "$MORTY_URL" ] && export SEARXNG_MORTY_URL="$MORTY_URL"
[ -n "$MORTY_KEY" ] && export SEARXNG_MORTY_KEY="$MORTY_KEY"

# Activate venv and start uWSGI as searxng user
. /usr/local/searxng/venv/bin/activate

echo "Listen on ${BIND_ADDRESS}"
gosu searxng:searxng uwsgi \
  --master \
  --plugin python3 \
  --virtualenv /usr/local/searxng/venv \
  --http-socket "${BIND_ADDRESS}" \
  --ini "${UWSGI_SETTINGS_PATH}" &

cd /usr/local/bin/  
llama-server -hf "$MODEL" -ngl 999 --ctx-size 8000 --port 1234 &
sleep 5
exec bplus-search &
exec bplus-launcher
