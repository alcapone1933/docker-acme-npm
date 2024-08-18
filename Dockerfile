FROM alcapone1933/alpine:latest
LABEL maintainer="alcapone1933 <alcapone1933@cosanostra-cloud.de>" \
      org.opencontainers.image.created="$(date +%Y-%m-%d\ %H:%M)" \
      org.opencontainers.image.authors="alcapone1933 <alcapone1933@cosanostra-cloud.de>" \
      org.opencontainers.image.url="https://hub.docker.com/r/alcapone1933/acme-npm" \
      org.opencontainers.image.version="v0.0.3" \
      org.opencontainers.image.ref.name="alcapone1933/acme-npm" \
      org.opencontainers.image.title="ACME-NPM" \
      org.opencontainers.image.description="Updater ACME-NPM-SSL"

ENV TZ=Europe/Berlin \
    LE_CONFIG_HOME="/acme.sh" \
    VERSION="v0.0.3" \
    CRON_TIME="" \
    SHOUTRRR_URL="" \
    SHOUTRRR_SKIP_TEST=no \
    NPM_API="" \
    NPM_USER="" \
    NPM_PASS="" \
    DOCKER_CONTAINER="" \
    PUID="0" \
    PGID="0"

RUN apk --update --no-cache add openssl openssh-client coreutils bind-tools curl sed socat tzdata \
    oath-toolkit-oathtool tar libidn jq git tini && \
    rm -rf /var/cache/apk/*

RUN git clone -b master https://github.com/acmesh-official/acme.sh.git /tmp/acme.sh && \
    cd /tmp/acme.sh && \
    /tmp/acme.sh/acme.sh --install --no-cron && \
    ln -s /root/.acme.sh/acme.sh /usr/local/bin/acme.sh && \
    rm -rf /tmp/acme.sh && \
    mkdir -p /data/log /usr/local/bin /etc/cron.d /output && touch /data/log/cron.log

COPY --chmod=0755 npm-add-certificate.sh /usr/local/bin
COPY --chmod=0755 npm-single.sh /usr/local/bin
COPY --chmod=0755 update-ssl.sh /usr/local/bin
COPY --chmod=0755 entrypoint.sh /usr/local/bin
COPY --chmod=0755 log-rotate.sh /usr/local/bin
COPY --chmod=0644 cronjob /etc/cron.d/container_cronjob
COPY --from=alcapone1933/shoutrrr:latest /usr/local/bin/shoutrrr /usr/local/bin/shoutrrr
COPY --from=alcapone1933/docker:dind /usr/local/bin/docker /usr/local/bin/docker

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD  ["/usr/local/bin/entrypoint.sh" ]
