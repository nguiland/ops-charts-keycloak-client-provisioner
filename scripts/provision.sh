#!/bin/sh

PATH="/opt/jq:${PATH}"
export PATH

set -eu

SCRIPT_DIR=/scripts

. "${SCRIPT_DIR}/common.sh"
. "${SCRIPT_DIR}/keycloak.sh"
. "${SCRIPT_DIR}/client.sh"
. "${SCRIPT_DIR}/kubernetes.sh"

initialize

log "Starting Keycloak client provisioning"

wait_for_keycloak
authenticate
ensure_realm
reconcile_client
synchronize_secret

log "Keycloak client provisioning completed successfully"
