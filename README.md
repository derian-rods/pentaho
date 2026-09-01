# Pentaho Server CE 9.4 con Docker Compose

## Pentaho

Pentaho Server Community Edition 9.4.0.0-343.

## Requisitos

Docker Desktop con Docker Compose, el ZIP local `./pentaho-server-ce-9.4.0.0-343.zip` y al menos unos 4 GB libres para el laboratorio.

## Arquitectura

```text
Browser
   |
   v
localhost:8090
   |
   v
Pentaho Server CE 9.4
   |
   | Docker network
   v
PostgreSQL
```

PostgreSQL no publica `5432` al host. Solo es accesible desde la red Docker `pentaho-net` como `repository:5432`.

## ZIP utilizado

```text
./pentaho-server-ce-9.4.0.0-343.zip
```

Descarga el ZIP Community Edition desde este release:

```text
https://github.com/ambientelivre/legacy-pentaho-ce/releases/download/pentaho-server-ce-9.4.0.0-343/pentaho-server-ce-9.4.0.0-343.zip
```

El archivo debe llamarse exactamente:

```text
pentaho-server-ce-9.4.0.0-343.zip
```

Después de descargarlo, colócalo en la raíz de este proyecto, junto a `docker-compose.yml`. El ZIP no se sube a GitHub porque está excluido por `.gitignore`.

## Arrancar

```bash
docker compose up -d --build
```

## Estado

```bash
docker compose ps
```

## Logs

```bash
./scripts/logs.sh
```

## Verificar

```bash
./scripts/verify-installation.sh
```

## Parar

```bash
docker compose down
```

Esto no borra las bases porque PostgreSQL usa el volumen Docker `pentaho-postgres-data`. También se conserva el estado local específico de Jackrabbit en `pentaho-jackrabbit-data`, necesario para que sus índices y metadatos locales sigan consistentes con las tablas PostgreSQL.

## Reiniciar

```bash
docker compose restart
```

## Acceso

```text
http://localhost:8090/pentaho
```

Si `PENTAHO_HTTP_PORT` cambia en `.env`, usa ese puerto.

## Backup

```bash
./scripts/backup.sh
```

Los backups se escriben en `./backups/<timestamp>/` y no se incluyen en Git.

## Conectar con Oracle

La imagen instala el driver oficial `ojdbc8` 19.22.0.0 desde Maven Central en `tomcat/lib`. Esta versión es compatible con Java 11.

En una conexión de tipo `Generic database`, usa esta clase:

```text
oracle.jdbc.OracleDriver
```

Para un `SERVICE_NAME`, la URL es:

```text
jdbc:oracle:thin:@//HOST:1521/SERVICE_NAME
```

Para un SID, la URL es:

```text
jdbc:oracle:thin:@HOST:1521:SID
```

Después de incorporar o actualizar el driver, reconstruye solo Pentaho. Este procedimiento no elimina los volúmenes:

```bash
docker compose build pentaho-server
docker compose up -d --force-recreate pentaho-server
docker compose exec pentaho-server find /opt/pentaho-server -name 'ojdbc*.jar'
```

### VPN corporativa con Podman y WSL2

Si Windows conecta con la base de datos mediante VPN pero Pentaho devuelve `Unknown host specified` o `The Network Adapter could not establish the connection`, comprueba por separado el DNS y el puerto desde el contenedor:

```powershell
podman exec pentaho-server getent hosts HOST_ORACLE
podman exec pentaho-server nc -vz -w 5 HOST_ORACLE 1521
```

`Unknown host specified` indica que Podman no resuelve el DNS corporativo. Un `Connection timed out` después de resolver el host indica que WSL2/Podman no puede enrutar el tráfico por la VPN. Confirma primero que Windows sí tiene acceso:

```powershell
Resolve-DnsName HOST_ORACLE
Test-NetConnection HOST_ORACLE -Port 1521
```

Cuando Windows conecta pero el contenedor no, habilita el networking de usuario de la máquina Podman para que su tráfico salga a través de Windows y de la VPN:

```powershell
podman compose stop
podman machine stop
podman machine set --user-mode-networking=true
podman machine start
podman compose up -d
```

Verifica nuevamente la conexión antes de probarla en Pentaho:

```powershell
podman exec pentaho-server nc -vz -w 5 HOST_ORACLE 1521
```

El resultado esperado contiene `succeeded`. Este procedimiento no borra imágenes ni volúmenes. No uses `network_mode: host`, porque en Windows representa la máquina Linux de Podman, no el host Windows, y además elimina la resolución interna del servicio `repository`. Tampoco uses `docker compose down -v` para este problema.

## Reset del laboratorio

Para reiniciar Pentaho sin borrar bases:

```bash
docker compose down
docker compose up -d
```

Para borrar completamente los datos del LAB, detén primero el proyecto y elimina los volúmenes explícitamente:

```bash
docker compose down
docker volume rm pentaho-postgres-data
docker volume rm pentaho-jackrabbit-data
```

No ejecutes ese borrado si quieres conservar repositorios, usuarios o contenido de Pentaho.

## Notas de implementación

La imagen Pentaho se construye desde `pentaho-server-ce-9.4.0.0-343.zip` y añade el driver oficial de Oracle desde Maven Central. El ZIP se copia durante el build, se descomprime dentro de la imagen y se elimina de la capa temporal. Tomcat se ejecuta en foreground con `catalina.sh run`, no con `start-pentaho.sh`, porque el script original lanza Tomcat en background.

PostgreSQL usa la versión 14 por compatibilidad con el driver incluido `postgresql-42.2.23.jar` y los SQL oficiales de Pentaho ubicados en `data/postgresql/` dentro del ZIP.
