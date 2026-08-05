## Context

`docker-compose.yml` hoy hardcodea `TZ: 'America/Costa_Rica'` y `FTLCONF_webserver_acl: '+192.168.90.0/24,+127.0.0.1'` — dos valores que el propio `README.md` ya advierte que hay que ajustar por instalación. El repo ya tiene un mecanismo probado para esto: `.env` (gitignored) + interpolación nativa de Docker Compose (`${VAR}`), usado hoy solo para `PIHOLE_PASSWORD`. Se confirmó en la sesión de exploración previa, contra la documentación oficial de `docker/compose` y con una prueba empírica (`docker compose config`), que la interpolación funciona embebida dentro de un string más grande (ej. `'+${LAN_SUBNET},+127.0.0.1'`), no solo cuando el valor completo es una variable.

Por separado, `./etc-dnsmasq.d:/etc/dnsmasq.d` es un bind mount sin efecto: `misc.etc_dnsmasq_d = false` en `pihole.toml`, ningún `FTLCONF_misc_etc_dnsmasq_d` lo activa, y el directorio en el host está vacío. Pi-hole v6 ya cubre el caso de uso que motivaría este mount (líneas dnsmasq custom) vía `misc.dnsmasq_lines`, configurable por env var igual que el resto de este compose.

Ya existe precedente reciente y directamente relevante: el change anterior (`harden-pihole-dns-only-production`) tuvo que resolver en producción un `FTLCONF_webserver_acl` mal formado (`check_acl: subnet must be [+|-]IP-addr[/x]`) por un delimitador incorrecto. Cualquier cambio que vuelva a tocar esta misma variable hereda la responsabilidad de no repetir ese modo de falla.

## Goals / Non-Goals

**Goals:**
- Externalizar `TZ` y la subnet LAN de `FTLCONF_webserver_acl` a `.env`, sin que `docker-compose.yml` pierda la forma revisable de la política de ACL (default-deny + LAN + localhost).
- Quitar el bind mount `etc-dnsmasq.d` del servicio `pihole` de forma limpia (compose, README, `.gitignore` coherentes entre sí).
- Que un `.env` incompleto falle rápido y con un mensaje claro en vez de producir silenciosamente una ACL rota (la lección del change anterior).

**Non-Goals:**
- No se tocan `FTLCONF_dns_dnssec`, `FTLCONF_dns_listeningMode`, `FTLCONF_dns_rateLimit_*`, `FTLCONF_webserver_session_timeout` ni `FTLCONF_ntp_*` — decisiones de arquitectura ya cerradas, no hechos de despliegue.
- No se activa `FTLCONF_misc_etc_dnsmasq_d` ni se reintroduce el mount bajo ninguna forma — decisión explícita del usuario.
- No se agrega soporte IPv6 a la ACL del webserver.
- No se toca la regla de firewall/DNAT pendiente (fuera de alcance, ya documentada como pendiente crítico separado).

## Decisions

### 1. Interpolación nativa de Compose (`${VAR}`), no un mecanismo de FTLCONF
Se usa `${TZ}` y `${LAN_SUBNET}` — sustitución que hace Docker Compose al parsear el YAML, antes de que el valor llegue al contenedor — en vez de, por ejemplo, un único env var con la ACL completa. Confirmado (docs + prueba empírica) que la sustitución funciona embebida dentro de un string (`'+${LAN_SUBNET},+127.0.0.1'`), preservando el resto de los caracteres.

Alternativa considerada — una sola variable `.env` con la ACL completa (`FTLCONF_WEBSERVER_ACL=+192.168.90.0/24,+127.0.0.1`): descartada. Esconde la forma de la política (quién puede acceder al panel: LAN + localhost, todo lo demás denegado) fuera de `docker-compose.yml`, que es el archivo trackeado donde un futuro cambio de esa política sí debe quedar visible en el diff.

### 2. `LAN_SUBNET` con guard `${LAN_SUBNET:?...}`, `TZ` sin guard
Compose soporta la sintaxis `${VAR:?mensaje de error}` para exigir que una variable esté definida, fallando el `docker compose up` con un mensaje claro en vez de continuar con un valor vacío. Se usa para `LAN_SUBNET` porque un valor vacío produce `FTLCONF_webserver_acl: '+,+127.0.0.1'` — exactamente el tipo de ACL malformada que ya rompió el webserver una vez (`check_acl: subnet must be [+|-]IP-addr[/x]`). No se aplica el mismo guard a `TZ`: un valor vacío ahí no rompe nada, el contenedor simplemente cae a UTC — un defecto de menor severidad, documentado pero no bloqueante.

Alternativa considerada — guard también en `TZ`: descartada, agregaría fricción (obligar a definir el huso horario) para un fallo que no es destructivo, a diferencia de la ACL.

### 3. Quitar el mount de `etc-dnsmasq.d` en vez de activarlo
`misc.etc_dnsmasq_d` se deja en su default (`false`) — no se agrega `FTLCONF_misc_etc_dnsmasq_d`, no hay nada que fijar porque el default ya es el valor deseado. El mount se elimina de `docker-compose.yml` sin reemplazo: si en el futuro hace falta una directiva dnsmasq custom, `misc.dnsmasq_lines` (vía `FTLCONF_misc_dnsmasq_lines`) ya cubre ese caso de uso con el mismo patrón reproducible que el resto del compose, sin volver a depender de un archivo suelto en el host.

### 4. Limpieza coherente de README y `.gitignore`
Como Docker ya no va a crear `./etc-dnsmasq.d` al hacer `up` (no hay mount que lo dispare), se quita la entrada `etc-dnsmasq.d/` de `.gitignore` y la mención en la sección "Estructura del repo" del README, y se actualiza la nota sobre `FTLCONF_webserver_acl` para reflejar que la subnet ahora vive en `.env`.

## Risks / Trade-offs

- **[Riesgo]** Un despliegue existente que actualice `docker-compose.yml` sin antes agregar `TZ`/`LAN_SUBNET` a su `.env` real (no `.env.example`) → **Mitigación**: el guard `${LAN_SUBNET:?...}` hace fallar `docker compose up` inmediatamente con un mensaje claro en vez de desplegar una ACL rota en silencio; `TZ` cae a UTC sin romper nada, documentado en el plan de migración.
- **[Riesgo]** Alguien interpreta el guard de `LAN_SUBNET` como validación de formato (ej. que rechaza un CIDR mal escrito) → **Mitigación**: no lo es, solo exige que la variable exista. La validación de formato de la ACL la sigue haciendo `check_acl` dentro del contenedor al arrancar — documentar esta distinción en el propio comentario del compose.
- **[Trade-off]** Los cuatro cambios (2 interpolaciones + 1 volumen removido) requieren recrear el contenedor `pihole`, igual que el change anterior — ya es un flujo conocido (`docker compose up -d`).

## Migration Plan

1. En cada `.env` real existente (no `.env.example`), agregar `TZ=<huso horario>` y `LAN_SUBNET=<subnet real de la LAN>` **antes** de actualizar `docker-compose.yml`.
2. Editar `docker-compose.yml`: `TZ: '${TZ}'`, `FTLCONF_webserver_acl: '+${LAN_SUBNET:?LAN_SUBNET debe estar definido en .env},+127.0.0.1'`, quitar la línea de volumen `etc-dnsmasq.d`.
3. Actualizar `.env.example`, `README.md` y `.gitignore` según las Decisiones 2 y 4.
4. Verificar localmente con `docker compose config` (sin levantar nada) que `TZ` y `FTLCONF_webserver_acl` resuelven a los valores esperados antes de tocar producción.
5. `docker compose up -d` en el host de producción — recrea `pihole`.
6. Confirmar que el webserver arranca bien (`docker compose logs pihole | grep -i webserver`) y que `etc-dnsmasq.d/` no se vuelve a crear tras un ciclo `down`/`up` limpio.
7. Rollback: revertir `docker-compose.yml`/`.env.example`/`README.md`/`.gitignore` y `docker compose up -d` de nuevo. Las variables `TZ`/`LAN_SUBNET` en `.env` pueden quedarse (no rompen nada si el compose ya no las usa) o quitarse, indistinto.

## Open Questions

- ¿Se quita también el directorio `etc-dnsmasq.d/` ya existente en el host de producción, o se deja como remanente inofensivo (gitignored, sin mount que lo referencie)? No afecta funcionalidad ninguna de las dos opciones.
