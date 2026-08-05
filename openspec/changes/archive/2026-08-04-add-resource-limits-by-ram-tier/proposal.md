## Why

`docker-compose.yml` no declara ningún límite de memoria ni de CPU para `pihole` ni para `dnscrypt-proxy` — ambos contenedores pueden consumir toda la RAM/CPU disponible del host sin techo. Esto no es solo teórico: la propia documentación de mantenedores de Pi-hole FTL documenta memory leaks conocidos (`FTL_reload_all_domainlists`, `gravityDB_open`), y el stack está pensado para correr en Raspberry Pi, donde la RAM total puede ir de 2GB a 8GB según el modelo — un mismo límite fijo no tiene sentido en ambos extremos. Sin un techo, una fuga de memoria o un pico de CPU (ej. un flood de consultas) puede agotar los recursos del host completo, afectando a ambos contenedores del stack y a cualquier otro proceso que corra en esa misma Raspberry Pi.

## Goals / Non-Goals

**Goals:**
- Que `pihole` y `dnscrypt-proxy` tengan un techo de memoria y CPU configurable, evitando que uno de los dos agote los recursos del host.
- Que ese techo se pueda ajustar según la RAM real de la Raspberry Pi donde se despliega (2GB vs 8GB), sin editar `docker-compose.yml`.
- Aprovechar `restart: unless-stopped` (ya presente en ambos servicios): si un límite de memoria causa un OOM-kill del contenedor, el propio restart policy ya existente lo revive solo — el límite convierte una fuga lenta que ahogaría todo el host en un reinicio aislado y automático de un único contenedor.

**Non-Goals:**
- No se ajusta la rotación de logs, `maxDBdays` (queda en su default de 91 en `pihole.toml`), ni `dns.queryLogging` (se mantiene activo, por trazabilidad en el dashboard de Pi-hole) — quedó explícitamente descartado en la exploración previa a este proposal.
- No se resuelve la limpieza de `etc-pihole/config_backups/` ni `etc-pihole/gravity_backups/` — Pi-hole no expone ningún `FTLCONF_*` para su retención y no hay señal suficiente todavía para diseñar ese mecanismo; queda como hilo separado a explorar más adelante.
- No se toca el logging driver de Docker (`json-file`/`max-size`/`max-file`).
- No se agregan variables `.env` para esto — se decidió explícitamente el mecanismo de overlays (menos piezas que ajustar por instalación) sobre variables de entorno.
- No se toca la cadena de resolución DNS (device → Pi-hole → dnscrypt-proxy → upstream) — este change es puramente de gobernanza de recursos del host, no de política ni ruteo DNS.

## What Changes

- Se agregan dos overlays nuevos de Docker Compose, uno por tier de RAM de Raspberry Pi soportado (2GB y 8GB), que declaran `deploy.resources.limits` (memory y cpus) para los servicios `pihole` y `dnscrypt-proxy`. Mismo patrón que el overlay `docker-compose.test.yml` ya existente en el repo: se combinan con `-f` explícito, nunca se llaman `docker-compose.override.yml` (ese nombre se auto-mergea con cualquier `docker compose` suelto, lo cual en producción real aplicaría límites sin que nadie lo pida).
- `docker-compose.yml` base **no** declara ningún límite — los límites viven exclusivamente en los overlays de tier, igual que hoy el mapeo de puertos vive en base y `docker-compose.test.yml` lo ajusta.
- Se documenta en `README.md` cómo elegir y aplicar el overlay correspondiente al desplegar en producción (`docker compose -f docker-compose.yml -f docker-compose.pi-<tier>gb.yml up -d`), y se actualiza la sección "Estructura del repo" para listar los overlays nuevos.
- Se documenta en `CONTRIBUTING.md` la convención de nombres/tiers de estos overlays, reutilizando la misma justificación ya escrita ahí sobre por qué no se usa `docker-compose.override.yml`.

## Capabilities

### New Capabilities
- `container-resource-limits`: los servicios `pihole` y `dnscrypt-proxy` declaran límites de memoria y CPU aplicables vía overlays de Docker Compose seleccionables según la RAM del host, sin que el compose base imponga ningún techo por defecto.

### Modified Capabilities
(ninguna — no cambian requirements de `deployment-configuration`, `pihole-dns-only-deployment`, `dnscrypt-upstream-resolution` ni `dev-test-workflow`; este change introduce una capability nueva y separada)

## Impact

- `docker-compose.yml`: sin cambios de contenido — sirve como base sin límites, confirmado (contra el código fuente de `docker/compose`) que `deploy.resources.limits.cpus`/`memory` se aplican con `docker compose up` standalone, sin requerir modo Swarm ni cambios en el daemon de Docker.
- Archivos nuevos: overlays de límites por tier (ej. `docker-compose.pi-2gb.yml`, `docker-compose.pi-8gb.yml`) — nombres y valores exactos a definir en `design.md`.
- `README.md`: sección "Uso rápido" y "Estructura del repo" actualizadas.
- `CONTRIBUTING.md`: sección "Convenciones" actualizada con la convención de nombres de overlays de tier.
- Cadena de confianza DNS (device → Pi-hole → dnscrypt-proxy → upstream): sin cambios en ningún hop — este change no toca resolución, cifrado ni políticas DNS.
- `FTLCONF_webserver_acl` / firewall / DNAT: no aplica, este change no toca reglas de red ni ACLs.
- IPv4/IPv6: sin cambios de soporte — los límites de recursos son agnósticos a la familia IP de las consultas DNS que procesan los contenedores.
- No se agregan imágenes ni dependencias nuevas — los overlays son archivos de configuración de Compose puros, sin build ni imagen adicional; no aplica fijar versión/verificación.
