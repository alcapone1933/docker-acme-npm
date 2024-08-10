#!/usr/bin/env bash
DATUM=$(date +%Y-%m-%d\ %H:%M:%S)
# Pfad zur Zertifikatdatei
# CERT_PATH="/acme.sh/${DOMAIN}*/${DOMAIN}.cer"
CERT_PATH=$(find /acme.sh/${DOMAIN}* -type f -name "${DOMAIN}.cer" | head -n 1)
# Anzahl der Tage, die als Warnfrist verwendet werden
WARNING_DAYS=30

# Prüfen, ob die Zertifikatdatei existiert
if [ ! -f "$CERT_PATH" ]; then
    echo "$DATUM  FEHLER !!!  - Die Zertifikatdatei $CERT_PATH wurde nicht gefunden."
    exit 1
fi

# Ablaufdatum des Zertifikats auslesen
END_DATE=$(openssl x509 -in "$CERT_PATH" -noout -enddate | cut -d= -f2)

# Datum in Sekunden seit der Epoche konvertieren
END_DATE_SECONDS=$(date -d "$END_DATE" +%s)
CURRENT_DATE_SECONDS=$(date +%s)

# Differenz in Tagen berechnen
DIFF_DAYS=$(( (END_DATE_SECONDS - CURRENT_DATE_SECONDS) / 86400 ))

# Ausgabe und Überprüfung
if [ "$DIFF_DAYS" -le "$WARNING_DAYS" ]; then
    echo "=============================================================================================="
    echo "$DATUM    INFO !!!  - Warnung: Das Zertifikat läuft in weniger als $WARNING_DAYS Tagen ab."
    echo "$DATUM    INFO !!!  - Ablaufdatum: $END_DATE"
    echo "$DATUM    INFO !!!  - Resttage: $DIFF_DAYS"
    # DOCKER STOP
    if [ -z "${DOCKER_CONTAINER:-}" ] ; then
        echo > /dev/null
    else
        /usr/local/bin/docker stop ${DOCKER_CONTAINER}
    fi

    # ACME.SH
    /usr/local/bin/acme.sh --cron
    # NPM

    # OUTPUT file
    # if [ -z "${OUTPUT_YES:-}" ] ; then
    if [[ "${OUTPUT_YES}" =~ (NO|no|No) ]] ; then
        echo > /dev/null
    else
        # - CERT_CER_NAME=domain.cer
        cp -av /acme.sh/${DOMAIN}*/fullchain.cer /output/${CERT_CER_NAME:-${DOMAIN}.cer}
        # - CERT_KEY_NAME=domain.key
        cp -av /acme.sh/${DOMAIN}*/${DOMAIN}.key /output/${CERT_KEY_NAME:-}
        # - CERT_CSR_NAME=domain.csr
        cp -av /acme.sh/${DOMAIN}*/${DOMAIN}.csr /output/${CERT_CSR_NAME:-}
    fi

    # DOCKER START
    if [ -z "${DOCKER_CONTAINER:-}" ] ; then
        echo > /dev/null
    else
        /usr/local/bin/docker start ${DOCKER_CONTAINER}
    fi

    sleep 10

    if [ -z "${NPM_API:-}" ] ; then
        echo > /dev/null
    else
        CERT_FILE=$(find /acme.sh/${DOMAIN}* -type f -name "fullchain.cer" | head -n 1)
        KEY_FILE=$(find /acme.sh/${DOMAIN}* -type f -name "${DOMAIN}.key" | head -n 1)
        if [ -z "$CERT_FILE" ] || [ -z "$KEY_FILE" ]; then
            "$DATUM  FEHLER !!!  - NPM Certificate oder Key für ${DOMAIN} nicht gefuden."
        else
            API="${NPM_API}" \
            IDENTITY="${NPM_USER}" \
            SECRET="${NPM_PASS}" \
            /usr/local/bin/npm-add-certificate.sh -n "${DOMAIN}" -c "$CERT_FILE" -k "$KEY_FILE"
        fi
    fi

    if [ -z "${SHOUTRRR_URL:-}" ] ; then
        echo > /dev/null
    else
        echo "$DATUM  SHOUTRRR    - SHOUTRRR NACHRICHT wird gesendet"
        if ! /usr/local/bin/shoutrrr send --url "${SHOUTRRR_URL}" --message "`echo -e "$DATUM    INFO !!! \n\nUPDATE ACME-NPM \nSSL $DOMAIN"`" > /dev/null 2>&1; then
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
