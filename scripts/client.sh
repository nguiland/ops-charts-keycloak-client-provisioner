#!/bin/sh

find_client() {
  encoded_client_id=$(
    jq -rn --arg value "$CLIENT_ID" '$value | @uri'
  )

  url="${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=${encoded_client_id}"

  admin_request GET "$url"

  if [ "$HTTP_STATUS" != "200" ]; then
    error "Failed to find client '${CLIENT_ID}' (HTTP ${HTTP_STATUS}): ${HTTP_BODY}"
  fi

  CLIENT_UUID=$(
    printf '%s' "$HTTP_BODY" |
      jq -r --arg client_id "$CLIENT_ID" '
        [.[] | select(.clientId == $client_id)][0].id // empty
      '
  )

  if [ -n "$CLIENT_UUID" ]; then
    log "Found existing Keycloak client '${CLIENT_ID}' (${CLIENT_UUID})"
  else
    log "Keycloak client '${CLIENT_ID}' does not exist"
  fi
}

build_client_configuration() {
  jq -n \
    --arg clientId "$CLIENT_ID" \
    --arg name "$CLIENT_NAME" \
    --arg authenticatorType "$CLIENT_AUTHENTICATOR_TYPE" \
    --arg rootUrl "${CLIENT_ROOT_URL:-}" \
    --arg baseUrl "${CLIENT_BASE_URL:-}" \
    --argjson enabled "$CLIENT_ENABLED" \
    --argjson standardFlowEnabled "$CLIENT_STANDARD_FLOW_ENABLED" \
    --argjson directAccessGrantsEnabled "$CLIENT_DIRECT_ACCESS_GRANTS_ENABLED" \
    --argjson serviceAccountsEnabled "$CLIENT_SERVICE_ACCOUNTS_ENABLED" \
    --argjson implicitFlowEnabled "$CLIENT_IMPLICIT_FLOW_ENABLED" \
    --argjson redirectUris "$CLIENT_REDIRECT_URIS" \
    --argjson webOrigins "$CLIENT_WEB_ORIGINS" \
    --argjson frontchannelLogout "$CLIENT_FRONTCHANNEL_LOGOUT" \
    --argjson consentRequired "$CLIENT_CONSENT_REQUIRED" \
    --argjson attributes "$CLIENT_ATTRIBUTES" \
    '
    {
      clientId: $clientId,
      name: $name,
      enabled: $enabled,
      protocol: "openid-connect",
      publicClient: false,
      clientAuthenticatorType: $authenticatorType,
      standardFlowEnabled: $standardFlowEnabled,
      directAccessGrantsEnabled: $directAccessGrantsEnabled,
      serviceAccountsEnabled: $serviceAccountsEnabled,
      implicitFlowEnabled: $implicitFlowEnabled,
      redirectUris: $redirectUris,
      webOrigins: $webOrigins,
      frontchannelLogout: $frontchannelLogout,
      consentRequired: $consentRequired,
      attributes: $attributes
    }
    + (if $rootUrl != "" then {rootUrl: $rootUrl} else {} end)
    + (if $baseUrl != "" then {baseUrl: $baseUrl} else {} end)
    '
}

reconcile_client() {
  build_client_configuration > "$CLIENT_CONFIGURATION_FILE"

  find_client

  if [ -z "$CLIENT_UUID" ]; then
    log "Creating Keycloak client '${CLIENT_ID}'"

    desired_configuration=$(cat "$CLIENT_CONFIGURATION_FILE")

    admin_request \
      POST \
      "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients" \
      "$desired_configuration"

    if [ "$HTTP_STATUS" != "201" ]; then
      error "Failed to create client '${CLIENT_ID}' (HTTP ${HTTP_STATUS}): ${HTTP_BODY}"
    fi

    log "Keycloak client '${CLIENT_ID}' created successfully"

    find_client

    if [ -z "$CLIENT_UUID" ]; then
      error "Client '${CLIENT_ID}' was created but could not be found afterwards"
    fi

    return 0
  fi

  log "Updating Keycloak client '${CLIENT_ID}'"

  admin_request \
    GET \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_UUID}"

  if [ "$HTTP_STATUS" != "200" ]; then
    error "Failed to retrieve client '${CLIENT_ID}' (HTTP ${HTTP_STATUS}): ${HTTP_BODY}"
  fi

  printf '%s' "$HTTP_BODY" > "$EXISTING_CLIENT_FILE"

  merged_configuration=$(
    jq -s '
      .[0] as $existing
      | .[1] as $desired
      | ($existing * $desired)
      | .attributes = (
        ($existing.attributes // {})
        * ($desired.attributes // {})
      )
    ' "$EXISTING_CLIENT_FILE" "$CLIENT_CONFIGURATION_FILE"
  ) || error "Failed to merge existing and desired client configuration"

  admin_request \
    PUT \
    "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_UUID}" \
    "$merged_configuration"

  if [ "$HTTP_STATUS" != "204" ]; then
    error "Failed to update client '${CLIENT_ID}' (HTTP ${HTTP_STATUS}): ${HTTP_BODY}"
  fi

  log "Keycloak client '${CLIENT_ID}' updated successfully"
}