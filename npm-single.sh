#!/usr/bin/env bash
DATUM=$(date +%Y-%m-%d\ %H:%M:%S)
# Pfad zur Zertifikatdatei
# CERT_PATH="/acme.sh/${DOMAIN}*/${DOMAIN}.cer"
CERT_PATH=$(find /acme.sh/${DOMAIN}* -type f -name "${DOMAIN}.cer" | head -n 1)
# Anzahl der Tage, die als Warnfrist verwendet werden
WARNING_DAYS=30

# Funktion für Fehlerbehandlung
function handle_error() {
    DATUM_handle_error=$(date +%Y-%m-%d\ %H:%M:%S)
    local MESSAGE=$1
    echo "$DATUM_handle_error  FEHLER !!!  - $MESSAGE"

    if [ -n "${SHOUTRRR_URL:-}" ]; then
        echo "$DATUM_handle_error  SHOUTRRR    - SHOUTRRR NACHRICHT wird gesendet"
        if ! /usr/local/bin/shoutrrr send --url "${SHOUTRRR_URL}" --message "$(echo -e "ACME-NPM DOCKER \n$DATUM_handle_error    FEHLER !!! \n\n$MESSAGE")" > /dev/null 2>&1; then
            echo "$DATUM_handle_error  FEHLER !!!  - SHOUTRRR NACHRICHT konnte nicht gesendet werden"
        else
            echo "$DATUM_handle_error  SHOUTRRR    - SHOUTRRR NACHRICHT wurde gesendet"
        fi
    fi
    exit 1
}

# Prüfen, ob die Zertifikatdatei existiert
if [ ! -f "$CERT_PATH" ]; then
    handle_error "Die Zertifikatdatei ${DOMAIN}.cer wurde nicht gefunden."
fi

CERT_FILE=$(find /acme.sh/${DOMAIN}* -type f -name "fullchain.cer" | head -n 1)
KEY_FILE=$(find /acme.sh/${DOMAIN}* -type f -name "${DOMAIN}.key" | head -n 1)
if [ -z "$CERT_FILE" ] || [ -z "$KEY_FILE" ]; then
    handle_error "NPM-API Zertifikat oder Schlüssel für ${DOMAIN} nicht gefunden."
else
    if ! API="${NPM_API}" IDENTITY="${NPM_USER}" SECRET="${NPM_PASS}" /usr/local/bin/npm-add-certificate.sh -n "${DOMAIN}" -c "$CERT_FILE" -k "$KEY_FILE"; then
        handle_error "NPM-Zertifikat konnte nicht hinzugefügt werden."
    fi
fi
