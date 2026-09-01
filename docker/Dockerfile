FROM eclipse-temurin:11-jre

ARG PENTAHO_ZIP=pentaho-server-ce-9.4.0.0-343.zip
ARG OJDBC_VERSION=19.22.0.0
ARG OJDBC_SHA1=3f88f445f077ba486d8d8a4471f2a068d65b66cb

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bash \
      curl \
      unzip \
      fontconfig \
      fonts-dejavu \
      procps \
      netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system pentaho \
    && useradd --system --gid pentaho --home-dir /opt/pentaho --shell /bin/bash pentaho \
    && mkdir -p /opt/pentaho /opt/logs \
    && chown -R pentaho:pentaho /opt/pentaho /opt/logs

WORKDIR /opt
COPY ${PENTAHO_ZIP} /tmp/pentaho-server.zip
RUN unzip -q /tmp/pentaho-server.zip -d /opt \
    && rm /tmp/pentaho-server.zip \
    && curl -fsSL "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/${OJDBC_VERSION}/ojdbc8-${OJDBC_VERSION}.jar" \
      -o /opt/pentaho-server/tomcat/lib/ojdbc8.jar \
    && echo "${OJDBC_SHA1}  /opt/pentaho-server/tomcat/lib/ojdbc8.jar" | sha1sum -c - \
    && chmod +x /opt/pentaho-server/*.sh /opt/pentaho-server/tomcat/bin/*.sh \
    && chown -R pentaho:pentaho /opt/pentaho-server

COPY docker/entrypoint.sh /usr/local/bin/pentaho-entrypoint.sh
RUN bash -n /usr/local/bin/pentaho-entrypoint.sh \
    && chmod +x /usr/local/bin/pentaho-entrypoint.sh

WORKDIR /opt/pentaho-server
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/pentaho-entrypoint.sh"]
