## Why

`docker-compose.yml` mezcla dos tipos de valores en el bloque `environment:` del servicio `pihole`: decisiones de arquitectura del stack (DNSSEC, `listeningMode`, rate limiting) y hechos específicos de cada instalación (`TZ`, la subnet LAN dentro de `FTLCONF_webserver_acl`). Los segundos están hardcodeados en un archivo trackeado por git, pese a que el propio `README.md` ya advierte que hay que ajustarlos por instalación — cada quien despliegue este stack termina con un diff local sobre un archivo versionado, o mantiene un fork. Además, el volumen `./etc-dnsmasq.d:/etc/dnsmasq.d` está inerte: `misc.etc_dnsmasq_d = false` en `pihole.toml`, ningún `FTLCONF_misc_etc_dnsmasq_d` lo activa, y el directorio está vacío en el host. Pi-hole v6 ya cubre ese mismo caso de uso (inyectar líneas dnsmasq custom) vía `misc.dnsmasq_lines`, reproducible por env var como el resto de este compose — el mount no aporta nada hoy y no hay plan de activarlo.

## What Changes

- Mover `TZ` de valor hardcodeado en `docker-compose.yml` a variable `.env`, manteniendo `TZ: '${TZ}'` en el compose.
- Extraer la subnet LAN de `FTLCONF_webserver_acl` a una variable `.env` (`LAN_SUBNET`), manteniendo la forma de la ACL (`+${LAN_SUBNET},+127.0.0.1`) visible y revisable en `docker-compose.yml` — solo el CIDR específico de cada instalación se externaliza.
- Actualizar `.env.example` con `TZ` y `LAN_SUBNET` junto a `PIHOLE_PASSWORD`, documentados con valores de ejemplo (no reales).
- Quitar la línea `./etc-dnsmasq.d:/etc/dnsmasq.d` de los `volumes` del servicio `pihole`. `misc.etc_dnsmasq_d` se mantiene en su default (`false`); no se introduce ningún `FTLCONF_misc_etc_dnsmasq_d`.
- Actualizar `README.md` (la nota sobre `FTLCONF_webserver_acl`, la estructura del repo) y `.gitignore` para reflejar que `etc-dnsmasq.d/` ya no forma parte del stack.
- **No** se tocan `FTLCONF_dns_dnssec`, `FTLCONF_dns_listeningMode`, `FTLCONF_dns_rateLimit_*`, `FTLCONF_webserver_session_timeout` ni `FTLCONF_ntp_*` — son decisiones de arquitectura ya cerradas (ver `openspec/changes/archive/2026-08-04-harden-pihole-dns-only-production/`), no hechos de despliegue; parametrizarlas en `.env` les quitaría el rastro de revisión que tienen hoy en el diff de `docker-compose.yml`.

## Capabilities

### New Capabilities
- `deployment-configuration`: los valores específicos de cada instalación (huso horario, subnet LAN para la ACL del webserver) viven en `.env`, no hardcodeados en `docker-compose.yml`, sin perder la forma revisable de las decisiones de política que sí se mantienen en el compose.

### Modified Capabilities
- `pihole-dns-only-deployment`: se agrega el requirement de que el stack no declare bind mounts sin uso — el volumen `etc-dnsmasq.d` se retira porque la carga de `/etc/dnsmasq.d/` permanece desactivada y no hay contenido que persistir ahí.

## Impact

- `docker-compose.yml`: `TZ` y `FTLCONF_webserver_acl` pasan a interpolar variables `.env`; se quita el volumen `etc-dnsmasq.d`.
- `.env.example`: se agregan `TZ` y `LAN_SUBNET`.
- `README.md`: la nota sobre `FTLCONF_webserver_acl` se actualiza para reflejar que la subnet ahora vive en `.env`; la sección "Uso rápido" menciona `TZ`/`LAN_SUBNET` junto a `PIHOLE_PASSWORD`; se quita `etc-dnsmasq.d/` de "Estructura del repo".
- `.gitignore`: se quita la entrada `etc-dnsmasq.d/` (el directorio ya no lo crea el stack).
- Cadena de confianza DNS (device → Pi-hole → DNSCrypt-Proxy → upstream): sin cambios en ningún hop — este change es puramente de gestión de configuración de despliegue, no toca resolución, cifrado ni políticas DNS.
- IPv4/IPv6: sin cambios de soporte. `FTLCONF_webserver_acl` sigue siendo solo IPv4 (`LAN_SUBNET` + `127.0.0.1`), igual que hoy — este change no agrega ni quita alcance IPv6.
- No se agregan imágenes ni dependencias nuevas — no aplica fijar versión/verificación adicional.
- No requiere cambios en firewall/DNAT (pendiente documentado en el README, fuera de alcance de este change).
