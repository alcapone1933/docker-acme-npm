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
    # exit 1
}

# Prüfen, ob die Zertifikatdatei existiert
if [ ! -f "$CERT_PATH" ]; then
    handle_error "Die Zertifikatdatei ${DOMAIN}.cer wurde nicht gefunden."
fi

# Ablaufdatum des Zertifikats auslesen
END_DATE=$(openssl x509 -in "$CERT_PATH" -noout -enddate | cut -d= -f2)

# Prüfen, ob das Auslesen des Ablaufdatums erfolgreich war
if [ -z "$END_DATE" ]; then
    handle_error "Das Ablaufdatum des Zertifikats konnte nicht ausgelesen werden."
fi

# Datum in Sekunden seit der Epoche konvertieren
END_DATE_SECONDS=$(date -d "$END_DATE" +%s)
CURRENT_DATE_SECONDS=$(date +%s)

# Differenz in Tagen berechnen
TIME_DEFAULT=${TIME_DEFAULT:-86400}
DIFF_DAYS=$(( (END_DATE_SECONDS - CURRENT_DATE_SECONDS) / ${TIME_DEFAULT} ))

# Ausgabe und Überprüfung
if [ "$DIFF_DAYS" -le "$WARNING_DAYS" ]; then
    echo "=============================================================================================="
    echo "$DATUM    INFO !!!  - Warnung: Das Zertifikat läuft in weniger als $WARNING_DAYS Tagen ab."
    echo "$DATUM    INFO !!!  - Ablaufdatum: $END_DATE"
    echo "$DATUM    INFO !!!  - Resttage: $DIFF_DAYS"
    
    # DOCKER STOP
    if [ -n "${DOCKER_CONTAINER:-}" ] ; then
        if ! /usr/local/bin/docker stop ${DOCKER_CONTAINER}; then
            handle_error "Docker-Container ${DOCKER_CONTAINER} konnte nicht gestoppt werden."
        fi
    fi

    # ACME.SH
    if ! /usr/local/bin/acme.sh --cron; then
        handle_error "ACME.SH Cron-Job konnte nicht ausgeführt werden."
    fi

    # OUTPUT file
    if [[ "${OUTPUT_YES}" =~ (YES|yes|Yes) ]] ; then
        # - CERT_CER_NAME=domain.cer
        if ! cp -av /acme.sh/${DOMAIN}*/fullchain.cer /output/${CERT_CER_NAME:-${DOMAIN}.cer}; then
            handle_error "Zertifikatsdatei konnte nicht kopiert werden."
        fi
        # - CERT_KEY_NAME=domain.key
        if ! cp -av /acme.sh/${DOMAIN}*/${DOMAIN}.key /output/${CERT_KEY_NAME:-}; then
            handle_error "Schlüsseldatei konnte nicht kopiert werden."
        fi
        # - CERT_CSR_NAME=domain.csr
        if [[ "${CERT_CSR_NAME_YES}" =~ (YES|yes|Yes) ]] ; then
            if ! cp -av /acme.sh/${DOMAIN}*/${DOMAIN}.csr /output/${CERT_CSR_NAME:-}; then
                handle_error "CSR-Datei konnte nicht kopiert werden."
            fi
        fi
    fi

    # DOCKER START
    if [ -n "${DOCKER_CONTAINER:-}" ] ; then
        if ! /usr/local/bin/docker start ${DOCKER_CONTAINER}; then
            handle_error "Docker-Container ${DOCKER_CONTAINER} konnte nicht gestartet werden."
        fi
    fi

    sleep 10

    # NPM-API
    if [ -n "${NPM_API:-}" ] ; then
        CERT_FILE=$(find /acme.sh/${DOMAIN}* -type f -name "fullchain.cer" | head -n 1)
        KEY_FILE=$(find /acme.sh/${DOMAIN}* -type f -name "${DOMAIN}.key" | head -n 1)
        if [ -z "$CERT_FILE" ] || [ -z "$KEY_FILE" ]; then
            handle_error "NPM-API Zertifikat oder Schlüssel für ${DOMAIN} nicht gefunden."
        else
            if ! API="${NPM_API}" IDENTITY="${NPM_USER}" SECRET="${NPM_PASS}" /usr/local/bin/npm-add-certificate.sh -n "${DOMAIN}" -c "$CERT_FILE" -k "$KEY_FILE"; then
                handle_error "NPM-Zertifikat konnte nicht hinzugefügt werden."
            fi
        fi
    fi

    if [ -n "${SHOUTRRR_URL:-}" ] ; then
        echo "$DATUM  SHOUTRRR    - SHOUTRRR NACHRICHT wird gesendet"
        if ! /usr/local/bin/shoutrrr send --url "${SHOUTRRR_URL}" --message "$(echo -e "$DATUM    INFO !!! \n\nUPDATE ACME-NPM \nSSL $DOMAIN")" > /dev/null 2>&1; then
            echo "$DATUM  FEHLER !!!  - SHOUTRRR NACHRICHT konnte nicht gesendet werden"
        else
            echo "$DATUM  SHOUTRRR    - SHOUTRRR NACHRICHT wurde gesendet"
        fi
    fi
    echo "=============================================================================================="
else
    echo "=============================================================================================="
    echo "$DATUM    INFO !!!  - Das Zertifikat ist noch gültig für mehr als $WARNING_DAYS Tage."
    echo "$DATUM    INFO !!!  - Ablaufdatum: $END_DATE"
    echo "$DATUM    INFO !!!  - Resttage: $DIFF_DAYS"
    echo "=============================================================================================="
fi
