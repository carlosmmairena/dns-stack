## Why

Usar `docker-compose.test.yml` hoy requiere escribir `docker compose -f docker-compose.yml -f docker-compose.test.yml <comando>` cada vez, y repetir a mano la secuencia de verificación (logs, dig A/AAAA, simular caída de un resolver, revertir) que se hizo manualmente durante `add-upstream-dns-redundancy`. Eso es fricción real para cualquier dev que quiera probar un change antes de tocar el stack real, y es fácil hacerlo distinto cada vez. Un script con subcomandos lo vuelve un solo comando memorable, guiado y replicable — sin agregar dependencias nuevas al proyecto.

## Goals

- Reducir cada operación común (levantar, dig, logs, bajar) a un solo comando memorable.
- No agregar dependencias nuevas al proyecto — solo shell y `docker compose`, que ya son requisitos existentes.
- Dejar explícito en el propio script (vía `help`) por qué `docker-compose.test.yml` es un archivo separado y no `docker-compose.override.yml` (evitar que alguien lo renombre "para simplificar" y rompa el comportamiento en producción).

## Non-Goals

- No reemplaza ni modifica `docker-compose.yml` de producción.
- No es un test runner automatizado con aserciones pass/fail — sigue siendo verificación guiada para un humano, no CI. Automatizar aserciones queda para un change futuro si se necesita.
- No agrega Makefile ni `just` — se descartó explícitamente en la exploración previa por fricción de dependencias nuevas (`just` no está instalado en esta máquina; `make` no siempre está disponible en Raspberry Pi OS Lite).
- No automatiza la edición de `dnscrypt-proxy.toml` para simular caída de un resolver — el script **guía** los pasos manuales (ya validados en `add-upstream-dns-redundancy`), pero no muta archivos trackeados por sí solo, para evitar que un script de pruebas modifique config real sin que el dev lo note.

## What Changes

- Nuevo `scripts/dev-test.sh` (POSIX sh) con subcomandos:
  - `up` — levanta el stack con el overlay de pruebas (`docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --build`)
  - `down` — lo baja y limpia
  - `dig <dominio> [A|AAAA]` — corre `dig` contra Pi-hole vía el contenedor `dns-test`, default `A`
  - `logs [servicio]` — tail de logs, default `dnscrypt-proxy`
  - `status` — `ps` del overlay
  - `help` (default si no hay subcomando) — uso, y explica por el qué del nombre `.test.yml` vs `.override.yml`, y los pasos manuales guiados para simular caída de un resolver upstream (editar `server_names`/`disabled_server_names`, reiniciar, probar, revertir, reiniciar)
- Impacto en la cadena de confianza DNS (device -> Pi-hole -> DNSCrypt-Proxy -> upstream): **ninguno** — es tooling de desarrollo que envuelve comandos ya existentes de `docker compose`, no toca la resolución real ni ningún hop de la cadena.
- No requiere ajustar reglas de firewall/DNAT ni `FTLCONF_webserver_acl` — el script nunca publica puertos al host (hereda `ports: !reset []` de `docker-compose.test.yml`).
- Soporte IPv4/IPv6: el subcomando `dig` acepta explícitamente `A` o `AAAA` como segundo argumento, cubriendo ambas familias — no asume que verificar solo IPv4 alcanza.
- No se agrega ninguna imagen o dependencia nueva: reutiliza el servicio `dns-test` (`alpine:3.20`) ya declarado en `docker-compose.test.yml`; el script en sí solo requiere `sh` y `docker compose`, ya requisitos del proyecto.

## Capabilities

### New Capabilities
- `dev-test-workflow`: define el requisito de que cualquier dev tenga un único script con subcomandos guiados para levantar, verificar y bajar el stack de pruebas local, sin publicar puertos al host y sin dependencias nuevas.

### Modified Capabilities
(ninguna — no hay specs previas en `openspec/specs/`)

## Impact

- **Archivos afectados**: nuevo `scripts/dev-test.sh` (ejecutable). Posible mención breve en `README.md` (estructura del repo) o un `CONTRIBUTING.md` nuevo — a decidir en `design.md`, dado que el README ya se mantiene deliberadamente mínimo y enfocado en el usuario final, no en tooling de desarrollo.
- **Sistemas**: ninguno productivo; solo envuelve `docker-compose.test.yml` (ya existente) y `docker compose`.
- **Dependencias**: ninguna nueva — POSIX `sh` y `docker compose`, ya requeridos por el proyecto.
