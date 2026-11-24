#!/bin/sh

synchronize_secret() {
  log "Retrieving client secret for '${CLIENT_ID}'"

  url="${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_UUID}/client-secret"

  admin_request GET "$url"

  if [ "$HTTP_STATUS" != "200" ]; then
    error "Failed to retrieve client secret for '${CLIENT_ID}' (HTTP ${HTTP_STATUS}): ${HTTP_BODY}"
  fi

  CLIENT_SECRET=$(printf '%s' "$HTTP_BODY" | jq -er '.value') ||
    error "Could not extract client secret for '${CLIENT_ID}'"

  [ -n "$CLIENT_SECRET" ] ||
    error "Keycloak returned an empty client secret for '${CLIENT_ID}'"

  namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

  log "Synchronizing Kubernetes Secret '${OUTPUT_SECRET_NAME}'"

  secret_manifest=$(
    jq -n \
      --arg name "$OUTPUT_SECRET_NAME" \
      --arg namespace "$namespace" \
      --arg client_id_key "$OUTPUT_SECRET_CLIENT_ID_KEY" \
      --arg client_secret_key "$OUTPUT_SECRET_CLIENT_SECRET_KEY" \
      --arg client_id "$CLIENT_ID" \
      --arg client_secret "$CLIENT_SECRET" \
      '{
        apiVersion: "v1",
        kind: "Secret",
        metadata: {
          name: $name,
          namespace: $namespace
        },
        type: "Opaque",
        stringData: {
          ($client_id_key): $client_id,
          ($client_secret_key): $client_secret
        }
      }'
  ) || error "Failed to build Kubernetes Secret manifest"

  printf '%s' "$secret_manifest" | kubectl apply -f - ||
    error "Failed to synchronize Kubernetes Secret '${OUTPUT_SECRET_NAME}'"

  unset CLIENT_SECRET

  log "Kubernetes Secret '${OUTPUT_SECRET_NAME}' synchronized successfully"
}
