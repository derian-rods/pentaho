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

Descarga el ZIP Community Edition desde el sitio oficial de Pentaho/Hitachi Vantara o desde un mirror/archivo confiable que publique la edición CE. El archivo debe llamarse exactamente:

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

La imagen Pentaho se construye exclusivamente desde `pentaho-server-ce-9.4.0.0-343.zip`. El ZIP se copia durante el build, se descomprime dentro de la imagen y se elimina de la capa temporal. Tomcat se ejecuta en foreground con `catalina.sh run`, no con `start-pentaho.sh`, porque el script original lanza Tomcat en background.

PostgreSQL usa la versión 14 por compatibilidad con el driver incluido `postgresql-42.2.23.jar` y los SQL oficiales de Pentaho ubicados en `data/postgresql/` dentro del ZIP.
