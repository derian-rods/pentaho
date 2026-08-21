FROM postgres:14

ARG PENTAHO_ZIP=pentaho-server-ce-9.4.0.0-343.zip

RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*

COPY ${PENTAHO_ZIP} /tmp/pentaho-server.zip
RUN mkdir -p /opt/pentaho-sql \
    && unzip -q /tmp/pentaho-server.zip 'pentaho-server/data/postgresql/*' -d /opt/pentaho-sql \
    && rm /tmp/pentaho-server.zip

COPY postgres/init/10-init-pentaho.sh /docker-entrypoint-initdb.d/10-init-pentaho.sh
RUN chmod +x /docker-entrypoint-initdb.d/10-init-pentaho.sh
