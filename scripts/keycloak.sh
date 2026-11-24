#!/bin/sh

http_request() {
  method=$1
  url=$2
  body=${3:-}

  if [ -n "$body" ]; then
    HTTP_STATUS=$(
      curl \
        --silent \
        --show-error \
        --output "$HTTP_RESPONSE_FILE" \
        --write-out '%{http_code}' \
        --request "$method" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${ACCESS_TOKEN}" \
        --data "$body" \
        "$url"
    ) || error "HTTP request failed: ${method} ${url}"
  else
    HTTP_STATUS=$(
      curl \
        --silent \
        --show-error \
        --output "$HTTP_RESPONSE_FILE" \
        --write-out '%{http_code}' \
        --request "$method" \
        --header "Authorization: Bearer ${ACCESS_TOKEN}" \
        "$url"
    ) || error "HTTP request failed: ${method} ${url}"
  fi

  HTTP_BODY=$(cat "$HTTP_RESPONSE_FILE")
}

wait_for_keycloak() {
  url="${KEYCLOAK_URL}/realms/${KEYCLOAK_ADMIN_REALM}"

  log "Waiting for Keycloak at ${KEYCLOAK_URL}"

  attempt=1

  while [ "$attempt" -le "$READINESS_ATTEMPTS" ]; do
    status=$(
      curl \
        --silent \
        --output /dev/null \
        --write-out '%{http_code}' \
        "$url" || true
    )

    if [ "$status" = "200" ]; then
      log "Keycloak is ready"
      return 0
    fi

    log "Keycloak is not ready yet (attempt ${attempt}/${READINESS_ATTEMPTS})"

    attempt=$((attempt + 1))

    if [ "$attempt" -le "$READINESS_ATTEMPTS" ]; then
      sleep "$READINESS_INTERVAL_SECONDS"
    fi
  done

  error "Keycloak did not become ready after ${READINESS_ATTEMPTS} attempts"
}

authenticate() {
  url="${KEYCLOAK_URL}/realms/${KEYCLOAK_ADMIN_REALM}/protocol/openid-connect/token"

  log "Authenticating with Keycloak"

  HTTP_STATUS=$(
    curl \
      --silent \
      --show-error \
      --output "$HTTP_RESPONSE_FILE" \
      --write-out '%{http_code}' \
      --request POST \
      --header "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=password" \
      --data-urlencode "client_id=admin-cli" \
      --data-urlencode "username=${KEYCLOAK_ADMIN_USERNAME}" \
      --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
      "$url"
  ) || error "Keycloak authentication request failed"

  HTTP_BODY=$(cat "$HTTP_RESPONSE_FILE")

  if [ "$HTTP_STATUS" != "200" ]; then
    error "Keycloak authentication failed (HTTP ${HTTP_STATUS}): ${HTTP_BODY}"
  fi

  ACCESS_TOKEN=$(printf '%s' "$HTTP_BODY" | jq -er '.access_token') ||
    error "Could not extract access token from Keycloak response"

  log "Successfully authenticated with Keycloak"
}

admin_request() {
  method=$1
  url=$2
  body=${3:-}

  http_request "$method" "$url" "$body"
}

ensure_realm() {
  url="${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}"

  log "Checking Keycloak realm '${KEYCLOAK_REALM}'"

  admin_request GET "$url"

  case "$HTTP_STATUS" in
    200)
      log "Realm '${KEYCLOAK_REALM}' already exists"
      ;;
    404)
      log "Realm '${KEYCLOAK_REALM}' does not exist; creating it"

      realm_configuration=$(
        jq -n \
          --arg realm "$KEYCLOAK_REALM" \
          '{
            realm: $realm,
            enabled: true
          }'
      )

      admin_request POST "${KEYCLOAK_URL}/admin/realms" "$realm_configuration"

      if [ "$HTTP_STATUS" != "201" ]; then
        error "Failed to create realm '${KEYCLOAK_REALM}' (HTTP ${HTTP_STATUS}): ${HTTP_BODY}"
      fi

      log "Realm '${KEYCLOAK_REALM}' created successfully"
      ;;
    *)
      error "Failed to check realm '${KEYCLOAK_REALM}' (HTTP ${HTTP_STATUS}): ${HTTP_BODY}"
      ;;
  esac
}
