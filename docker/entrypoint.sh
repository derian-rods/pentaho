#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  HIBERNATE_DB HIBERNATE_USER HIBERNATE_PASSWORD
  QUARTZ_DB QUARTZ_USER QUARTZ_PASSWORD
  JACKRABBIT_DB JACKRABBIT_USER JACKRABBIT_PASSWORD
  PENTAHO_MIN_MEMORY PENTAHO_MAX_MEMORY
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required environment variable: ${var}" >&2
    exit 1
  fi
done

if ! getent hosts repository >/dev/null; then
  echo "Docker DNS cannot resolve repository" >&2
  exit 1
fi

until nc -z repository 5432; do
  echo "Waiting for PostgreSQL at repository:5432..."
  sleep 3
done

PENTAHO_HOME=/opt/pentaho-server
DI_HOME="${PENTAHO_HOME}/pentaho-solutions/system/kettle"

mkdir -p /opt/pentaho /opt/logs "${PENTAHO_HOME}/pentaho-solutions/system/jackrabbit/repository"
chown -R pentaho:pentaho /opt/pentaho /opt/logs "${PENTAHO_HOME}/pentaho-solutions/system/jackrabbit/repository"

cat > "${PENTAHO_HOME}/tomcat/webapps/pentaho/META-INF/context.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context path="/pentaho" docBase="webapps/pentaho/">
  <Resource name="jdbc/Hibernate" auth="Container" type="javax.sql.DataSource"
    factory="org.pentaho.di.core.database.util.DecryptingDataSourceFactory" maxActive="20" minIdle="0" maxIdle="5" initialSize="0"
    maxWait="10000" username="${HIBERNATE_USER}" password="${HIBERNATE_PASSWORD}"
    driverClassName="org.postgresql.Driver" url="jdbc:postgresql://repository:5432/${HIBERNATE_DB}"
    validationQuery="select 1" />

  <Resource name="jdbc/Quartz" auth="Container" type="javax.sql.DataSource"
    factory="org.pentaho.di.core.database.util.DecryptingDataSourceFactory" maxActive="20" minIdle="0" maxIdle="5" initialSize="0"
    maxWait="10000" username="${QUARTZ_USER}" password="${QUARTZ_PASSWORD}" testOnBorrow="true"
    driverClassName="org.postgresql.Driver" url="jdbc:postgresql://repository:5432/${QUARTZ_DB}"
    validationQuery="select 1" />

  <Resource name="jdbc/jackrabbit" auth="Container" type="javax.sql.DataSource"
    factory="org.pentaho.di.core.database.util.DecryptingDataSourceFactory" maxActive="20" minIdle="0" maxIdle="5" initialSize="0"
    maxWait="10000" username="${JACKRABBIT_USER}" password="${JACKRABBIT_PASSWORD}"
    driverClassName="org.postgresql.Driver" url="jdbc:postgresql://repository:5432/${JACKRABBIT_DB}"
    validationQuery="select 1" />
</Context>
EOF

cp "${PENTAHO_HOME}/pentaho-solutions/system/dialects/postgresql/hibernate/hibernate-settings.xml" \
  "${PENTAHO_HOME}/pentaho-solutions/system/hibernate/hibernate-settings.xml"
cp "${PENTAHO_HOME}/pentaho-solutions/system/dialects/postgresql/applicationContext-spring-security-hibernate.properties" \
  "${PENTAHO_HOME}/pentaho-solutions/system/applicationContext-spring-security-hibernate.properties"

perl -0pi -e 's#jdbc:postgresql://localhost:5432/hibernate#jdbc:postgresql://repository:5432/'"${HIBERNATE_DB}"'#g' \
  "${PENTAHO_HOME}/pentaho-solutions/system/hibernate/postgresql.hibernate.cfg.xml"

perl -0pi -e 's#\s*<!-- \[BEGIN HSQLDB DATABASES\] -->.*?<!-- \[END HSQLDB DATABASES\] -->##s; s#\s*<!-- \[BEGIN HSQLDB STARTER\] -->.*?<!-- \[END HSQLDB STARTER\] -->##s' \
  "${PENTAHO_HOME}/tomcat/webapps/pentaho/WEB-INF/web.xml"

perl -0pi -e 's#<PersistenceManager class="org\.apache\.jackrabbit\.core\.persistence\.pool\.H2PersistenceManager">\s*<param name="url" value="jdbc:h2:\$\{wsp\.home\}/db"/>\s*<param name="schemaObjectPrefix" value="\$\{wsp\.name\}_"/>\s*</PersistenceManager>#<PersistenceManager class="org.apache.jackrabbit.core.persistence.bundle.PostgreSQLPersistenceManager">\n      <param name="driver" value="javax.naming.InitialContext"/>\n      <param name="url" value="java:comp/env/jdbc/jackrabbit"/>\n      <param name="schema" value="postgresql"/>\n      <param name="schemaObjectPrefix" value="\${wsp.name}_pm_ws_"/>\n    </PersistenceManager>#s; s#<PersistenceManager class="org\.apache\.jackrabbit\.core\.persistence\.pool\.H2PersistenceManager">\s*<param name="url" value="jdbc:h2:\$\{rep\.home\}/version/db"/>\s*<param name="schemaObjectPrefix" value="version_"/>\s*</PersistenceManager>#<PersistenceManager class="org.apache.jackrabbit.core.persistence.bundle.PostgreSQLPersistenceManager">\n      <param name="driver" value="javax.naming.InitialContext"/>\n      <param name="url" value="java:comp/env/jdbc/jackrabbit"/>\n      <param name="schema" value="postgresql"/>\n      <param name="schemaObjectPrefix" value="pm_ver_"/>\n    </PersistenceManager>#s' \
  "${PENTAHO_HOME}/pentaho-solutions/system/jackrabbit/repository.xml"

perl -0pi -e 's#<FileSystem class="org\.apache\.jackrabbit\.core\.fs\.local\.LocalFileSystem">\s*<param name="path" value="\$\{rep\.home\}/repository"/>\s*</FileSystem>#<FileSystem class="org.apache.jackrabbit.core.fs.db.DbFileSystem">\n    <param name="driver" value="javax.naming.InitialContext"/>\n    <param name="url" value="java:comp/env/jdbc/jackrabbit"/>\n    <param name="schema" value="postgresql"/>\n    <param name="schemaObjectPrefix" value="fs_repos_"/>\n  </FileSystem>#s; s#<FileSystem class="org\.apache\.jackrabbit\.core\.fs\.local\.LocalFileSystem">\s*<param name="path" value="\$\{wsp\.home\}"/>\s*</FileSystem>#<FileSystem class="org.apache.jackrabbit.core.fs.db.DbFileSystem">\n      <param name="driver" value="javax.naming.InitialContext"/>\n      <param name="url" value="java:comp/env/jdbc/jackrabbit"/>\n      <param name="schema" value="postgresql"/>\n      <param name="schemaObjectPrefix" value="fs_ws_"/>\n    </FileSystem>#s; s#<FileSystem class="org\.apache\.jackrabbit\.core\.fs\.local\.LocalFileSystem">\s*<param name="path" value="\$\{rep\.home\}/version"\s*/>\s*</FileSystem>#<FileSystem class="org.apache.jackrabbit.core.fs.db.DbFileSystem">\n      <param name="driver" value="javax.naming.InitialContext"/>\n      <param name="url" value="java:comp/env/jdbc/jackrabbit"/>\n      <param name="schema" value="postgresql"/>\n      <param name="schemaObjectPrefix" value="fs_ver_"/>\n    </FileSystem>#s' \
  "${PENTAHO_HOME}/pentaho-solutions/system/jackrabbit/repository.xml"

CATALINA_HOME="${PENTAHO_HOME}/tomcat"
CATALINA_BASE="${PENTAHO_HOME}/tomcat"
CATALINA_OPTS="-Xms${PENTAHO_MIN_MEMORY} -Xmx${PENTAHO_MAX_MEMORY} -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Dfile.encoding=utf8 -Djava.locale.providers=COMPAT,SPI -DDI_HOME=${DI_HOME}"
JDK_JAVA_OPTIONS="${JDK_JAVA_OPTIONS:-} --add-opens=java.base/sun.net.www.protocol.jar=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.security=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.file=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.ftp=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.http=ALL-UNNAMED --add-opens=java.base/sun.net.www.protocol.https=ALL-UNNAMED"

exec runuser -u pentaho -- env \
  HOME=/opt/pentaho \
  JAVA_HOME="${JAVA_HOME:-/opt/java/openjdk}" \
  CATALINA_HOME="${CATALINA_HOME}" \
  CATALINA_BASE="${CATALINA_BASE}" \
  CATALINA_OPTS="${CATALINA_OPTS}" \
  JDK_JAVA_OPTIONS="${JDK_JAVA_OPTIONS}" \
  PATH="${PATH}" \
  bash -lc 'cd /opt/pentaho-server && exec "$CATALINA_HOME/bin/catalina.sh" run'
