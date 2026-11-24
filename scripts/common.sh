#!/bin/sh

log() {
  printf '[INFO] %s\n' "$*"
}

error() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_value() {
  value=$1
  name=$2

  if [ -z "$value" ]; then
    error "Required environment variable ${name} is missing"
  fi
}

initialize() {
  require_value "${KEYCLOAK_URL:-}" KEYCLOAK_URL
  require_value "${KEYCLOAK_ADMIN_REALM:-}" KEYCLOAK_ADMIN_REALM
  require_value "${KEYCLOAK_REALM:-}" KEYCLOAK_REALM
  require_value "${KEYCLOAK_ADMIN_USERNAME:-}" KEYCLOAK_ADMIN_USERNAME
  require_value "${KEYCLOAK_ADMIN_PASSWORD:-}" KEYCLOAK_ADMIN_PASSWORD

  require_value "${CLIENT_ID:-}" CLIENT_ID
  require_value "${CLIENT_NAME:-}" CLIENT_NAME
  require_value "${CLIENT_ENABLED:-}" CLIENT_ENABLED
  require_value "${CLIENT_AUTHENTICATOR_TYPE:-}" CLIENT_AUTHENTICATOR_TYPE
  require_value "${CLIENT_STANDARD_FLOW_ENABLED:-}" CLIENT_STANDARD_FLOW_ENABLED
  require_value "${CLIENT_DIRECT_ACCESS_GRANTS_ENABLED:-}" CLIENT_DIRECT_ACCESS_GRANTS_ENABLED
  require_value "${CLIENT_SERVICE_ACCOUNTS_ENABLED:-}" CLIENT_SERVICE_ACCOUNTS_ENABLED
  require_value "${CLIENT_IMPLICIT_FLOW_ENABLED:-}" CLIENT_IMPLICIT_FLOW_ENABLED
  require_value "${CLIENT_REDIRECT_URIS:-}" CLIENT_REDIRECT_URIS
  require_value "${CLIENT_WEB_ORIGINS:-}" CLIENT_WEB_ORIGINS
  require_value "${CLIENT_FRONTCHANNEL_LOGOUT:-}" CLIENT_FRONTCHANNEL_LOGOUT
  require_value "${CLIENT_CONSENT_REQUIRED:-}" CLIENT_CONSENT_REQUIRED
  require_value "${CLIENT_ATTRIBUTES:-}" CLIENT_ATTRIBUTES

  require_value "${OUTPUT_SECRET_NAME:-}" OUTPUT_SECRET_NAME
  require_value "${OUTPUT_SECRET_CLIENT_ID_KEY:-}" OUTPUT_SECRET_CLIENT_ID_KEY
  require_value "${OUTPUT_SECRET_CLIENT_SECRET_KEY:-}" OUTPUT_SECRET_CLIENT_SECRET_KEY

  require_value "${READINESS_ATTEMPTS:-}" READINESS_ATTEMPTS
  require_value "${READINESS_INTERVAL_SECONDS:-}" READINESS_INTERVAL_SECONDS

  WORK_DIR=$(mktemp -d)
  HTTP_RESPONSE_FILE="${WORK_DIR}/response"
  CLIENT_CONFIGURATION_FILE="${WORK_DIR}/client.json"
  EXISTING_CLIENT_FILE="${WORK_DIR}/existing-client.json"

  KEYCLOAK_URL=${KEYCLOAK_URL%/}

  trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM
}
