#!/usr/bin/env bash
DATUM=$(date +%Y-%m-%d\ %H:%M:%S)
# Define cleanup procedure
term_handler() {
    echo "=============================================================================================="
    echo "======================================= STOP ACME-NPM ========================================"
    echo "=============================================================================================="
    kill -SIGTERM "$killpid"
    wait "$killpid" -f 2>/dev/null
    exit 143;
}

echo "=============================================================================================="
echo "======================================= START ACME-NPM ======================================="
echo "=============================================================================================="
sleep 10
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Trap SIGTERM
trap 'kill ${!}; term_handler' SIGTERM
################################
# Set user and group ID
if [ "$PUID" != "0" ] || [ "$PGID" != "0" ]; then
    chown -R "$PUID":"$PGID" /data
    if [ ! -d "/data/log" ]; then
        install -d -o $PUID -g $PGID -m 755 /data/log
    fi
    if [ ! -f "/data/log/cron.log" ]; then
        install -o $PUID -g $PGID -m 644 /dev/null /data/log/cron.log
    fi
    echo "$DATUM  RECHTE      - Ornder /data UID: $PUID and GID: $PGID"
fi
if [ ! -d "/data/log" ]; then
    install -d -o $PUID -g $PGID -m 755 /data/log
fi
if [ ! -f "/data/log/cron.log" ]; then
    install -o $PUID -g $PGID -m 644 /dev/null /data/log/cron.log
fi
################################
if [ -z "${SHOUTRRR_URL:-}" ] ; then
    echo "$DATUM  SHOUTRRR    - Sie haben keine SHOUTRRR URL gesetzt"
else
    echo "$DATUM  SHOUTRRR    - Sie haben eine  SHOUTRRR URL gesetzt"
    if [[ "${SHOUTRRR_SKIP_TEST}" =~ (NO|no|No) ]] ; then
        if ! /usr/local/bin/shoutrrr send --url "${SHOUTRRR_URL}" --message "`echo -e "$DATUM  TEST !!! \nACME-NPM Updater in Docker"`" > /dev/null 2>&1; then
            echo "$DATUM  FEHLER !!!  - Die Angaben sind falsch  gesetzt: SHOUTRRR URL"
            echo "$DATUM    INFO !!!  - Schaue unter https://containrrr.dev/shoutrrr/ nach dem richtigen URL Format"
            echo "$DATUM    INFO !!!  - Stoppen sie den Container und Starten sie den Container mit den richtigen Angaben erneut"
            sleep infinity
        else
            echo "$DATUM  CHECK       - Die Angaben sind richtig gesetzt: SHOUTRRR URL"
        fi
    else
        echo "$DATUM  SHOUTRRR    - Sie haben die Shoutrrr Testnachricht übersprungen."
    fi

fi

if [ -z "${DOCKER_CONTAINER:-}" ] ; then
    echo > /dev/null
else
    while true; do
    if ! /usr/local/bin/docker info > /dev/null 2>&1; then
        echo "$DATUM  FEHLER !!!  - Sie haben keine Verbinfung zum DOCKER-SOCKET"
        echo "$DATUM    INFO !!!  - Stoppen sie den Container und Starten sie den Container mit den richtigen Angaben erneut"
        sleep infinity
    else
        echo "$DATUM  CHECK       - DOCKER-SOCKET OK"
        break
    fi
    done
fi

if [ -z "${NPM_API:-}" ] ; then
    echo > /dev/null
else
    sleep 10
    while true; do
    response=$(curl --write-out "%{http_code}" --silent --output /dev/null --location --request POST "$NPM_API/tokens" --form "identity=$NPM_USER" --form "secret=$NPM_PASS")
    if [ "$response" -ne 200 ]; then
        echo "$DATUM  FEHLER !!!  - Sie haben keine Verbinfung zur NPM API"
        echo "$DATUM    INFO !!!  - Stoppen sie den Container und Starten sie den Container mit den richtigen Angaben erneut"
        sleep 600
    else
        echo "$DATUM  CHECK       - NPM-API OK"
        break
    fi
    done
fi

if [ -z "${CRON_TIME:-}" ] ; then
    echo > /dev/null
else
    sed -i "s#\0 \8 \* \* \*#$CRON_TIME#g" /etc/cron.d/container_cronjob
fi

MAX_LINES=1 /usr/local/bin/log-rotate.sh

/usr/bin/crontab /etc/cron.d/container_cronjob
/usr/sbin/crond

sleep 5

#set tail -f /data/log/cron.log "$@"
#exec "$@" &
tail -f /data/log/cron.log &
killpid="$!"
while true
do
    wait $killpid
    exit 0;
done
