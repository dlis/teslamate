#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

SETTINGS="${PWD}/settings.env"
SERVICES="${PWD}/services.yml"
DATABASE="${PWD}/database.tmp"
POSTGRES=18

function style() {
  local msg && msg="$(tput setaf "${1}")${2}"
  test -z "${3-}" || msg+=" $(tput bold)${3}"
  echo -e -n "${msg}$(tput sgr0)"
}

function prompt() {
  while :; do
    style 6 "${1} [and press Enter]: "
    read -r
    test -z "${REPLY}" || return 0
  done
}

function confirm() {
  while :; do
    style 6 "${1} [Y/N] "
    read -r -s -n 1
    [[ "${REPLY}" =~ ^y|Y$ ]] && echo "Y" && sleep 1 && return 0
    [[ "${REPLY}" =~ ^n|N$ ]] && echo "N" && sleep 1 && return 1
    style 1 "${REPLY} is a wrong answer\n"
  done
}

function rand() {
  openssl rand -base64 ${1} | tr -dc 'A-Za-z0-9' | head -c ${1}
}

# Install Docker if missing
command -v docker &>/dev/null || curl -fsSL https://get.docker.com | sh

# Generate a config if missing
if test ! -e "${SETTINGS}"; then
  if confirm "Is your Tesla for the Chinese market?"; then
    API_HOST="https://owner-api.vn.cloud.tesla.cn"
    WSS_HOST="wss://streaming.vn.cloud.tesla.cn"
  else
    API_HOST="https://owner-api.teslamotors.com"
    WSS_HOST="wss://streaming.vn.teslamotors.com"
  fi
  if confirm "Do you want to host TeslaMate on a public server?"; then
    prompt "Specify a domain name pointing to this server" && DOMAIN="${REPLY}"
  else
    DOMAIN="localhost"
  fi
  prompt "Specify a username for accessing TeslaMate" && USERNAME="${REPLY}"
  cat >"${SETTINGS}" <<EOL
# Following settings can be changed:
TIMEZONE=Europe/Minsk
DOMAIN=${DOMAIN}
USERNAME=${USERNAME}

# Changing following settings can damage the stack:
TESLA_API_HOST=${API_HOST}
TESLA_WSS_HOST=${WSS_HOST}
ENCRYPTION_SECRET=$(rand 50)
DATABASE_PASSWORD=$(rand 50)
EOL

# Read the config
fi; source "${SETTINGS}"

# Backup database to upgrade postgres
if test -e "${SERVICES}"; then
  docker compose --file "${SERVICES}" up --detach database && until \
  docker compose --file "${SERVICES}" exec -T database pg_isready -U teslamate &>/dev/null; do sleep 1; done && \
  docker compose --file "${SERVICES}" exec -T database pg_config --version | grep -oE '[0-9]+' | head -n1 | grep -vq "${POSTGRES}" && { \
    confirm "Upgrading postgres is needed. Would you like to create a backup with old data, upgrade postgres and restore the backup?" || exit 0
    docker compose --file "${SERVICES}" exec -T database pg_dump -U teslamate teslamate > "${DATABASE}" || { rm -f "${DATABASE}"; exit 1; }
  }
fi

# Generate a stack file
cat >"${SERVICES}" <<EOL
services:
  caddy:
    image: caddy:2-alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy-conf:/etc/caddy
      - caddy-data:/data
  teslamate:
    image: teslamate/teslamate:latest
    restart: always
    depends_on:
      - database
    environment:
      - DATABASE_HOST=database
      - DATABASE_NAME=teslamate
      - DATABASE_USER=teslamate
      - DATABASE_PASS=${DATABASE_PASSWORD}
      - ENCRYPTION_KEY=${ENCRYPTION_SECRET}
      - VIRTUAL_HOST=${DOMAIN}
      - TZ=${TIMEZONE}
      - TESLA_API_HOST=${TESLA_API_HOST}
      - TESLA_WSS_HOST=${TESLA_WSS_HOST}
      - CHECK_ORIGIN=true
      - DISABLE_MQTT=true
    cap_drop:
      - all
  grafana:
    image: teslamate/grafana:latest
    restart: always
    environment:
      - DATABASE_HOST=database
      - DATABASE_NAME=teslamate
      - DATABASE_USER=teslamate
      - DATABASE_PASS=${DATABASE_PASSWORD}
      - GF_AUTH_DISABLE_LOGIN_FORM=true
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_SERVER_DOMAIN=${DOMAIN}
      - GF_SERVER_ROOT_URL=%(protocol)s://%(domain)s/grafana
    volumes:
      - grafana:/var/lib/grafana
  database:
    image: postgres:${POSTGRES}
    restart: always
    environment:
      - POSTGRES_DB=teslamate
      - POSTGRES_USER=teslamate
      - POSTGRES_PASSWORD=${DATABASE_PASSWORD}
    volumes:
      - database:/var/lib/postgresql
volumes:
  caddy-conf:
  caddy-data:
  grafana:
  database:
EOL

# Update the stack
docker compose --file "${SERVICES}" pull

# Generate a password, a session token and a password hash
PASSWORD="$(rand 30)"
SESSION="$(rand 50)"
HASH="$(printf '%s\n' "${PASSWORD}" | docker run --rm --interactive caddy:2-alpine caddy hash-password)"

# Generate a Caddyfile, secrets are passed through stdin to keep them out of the process list
docker compose --file "${SERVICES}" up --detach caddy
docker compose --file "${SERVICES}" exec -T caddy sh -c "cat > /etc/caddy/Caddyfile" <<EOL
${DOMAIN} {
  route {
    # WebKit does not send Basic Auth credentials on WebSocket handshakes
    # (https://bugs.webkit.org/show_bug.cgi?id=80362), so only handshakes of
    # the known endpoints are authenticated by the cookie issued below, any
    # other request is always authenticated by the password. The route block
    # keeps basic_auth ahead of the header directive, otherwise the default
    # order applies and the cookie leaks in unauthorized responses
    @unauthenticated {
      not {
        path /live/websocket /grafana/api/live/ws
        header Upgrade websocket
        header_regexp Cookie "(^|;\s*)caddy_session=${SESSION}(\s*;|\$)"
      }
    }
    basic_auth @unauthenticated {
      ${USERNAME} ${HASH}
    }
    @unauthorized not header_regexp Cookie "(^|;\s*)caddy_session=${SESSION}(\s*;|\$)"
    header @unauthorized +Set-Cookie "caddy_session=${SESSION}; Secure; HttpOnly; SameSite=Lax; Path=/"
    encode zstd gzip
    handle_path /grafana* {
      reverse_proxy grafana:3000
    }
    reverse_proxy teslamate:4000
  }
}
EOL

# Stop the stack
docker compose --file "${SERVICES}" down --remove-orphans

# Restore the backup if exists
if test -s "${DATABASE}"; then
  docker compose --file "${SERVICES}" down --volumes grafana database && \
  docker compose --file "${SERVICES}" up --detach database && until \
  docker compose --file "${SERVICES}" exec -T database pg_isready -U teslamate &>/dev/null; do sleep 1; done && \
  docker compose --file "${SERVICES}" exec -T database psql -U teslamate -d teslamate < "${DATABASE}" && rm -f "${DATABASE}"
fi

# Start the stack
docker compose --file "${SERVICES}" up --detach

# Show next instructions
style 2 "
Save the following credentials, they will be used to log in to TeslaMate:
– a username \"${USERNAME}\" (was specified by you),
– a password \"${PASSWORD}\" (was generated automatically).

If it is a fresh installation, do the following additional steps:
1. Go to https://${DOMAIN}/ with your browser, log in with the username \
and the password mentioned above if needed, specify an access token and \
a refresh token which can be generated with an application named Auth my \
Tesla, and click \"Sign in\".
2. Go to https://${DOMAIN}/settings with your browser, log in with the \
username and the password mentioned above if needed, and specify URLs:
– \"https://${DOMAIN}\" as URL for the web app,
– \"https://${DOMAIN}/grafana\" as URL for the dashboards.

Enjoy using TeslaMate!\n"