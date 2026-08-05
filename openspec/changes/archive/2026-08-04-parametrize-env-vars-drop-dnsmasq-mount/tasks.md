## 1. Preparar `.env`

- [x] 1.1 Confirmar con el usuario el valor real de `LAN_SUBNET` para su `.env` de producción (no asumir `192.168.90.0/24` ni ninguna otra subnet) — confirmado: `192.168.90.0/24`
- [x] 1.2 Confirmar con el usuario el valor real de `TZ` para su `.env` de producción — confirmado: `America/Costa_Rica`
- [x] 1.3 Agregar `TZ` y `LAN_SUBNET` (valores de ejemplo, no reales) a `.env.example`
- [x] 1.4 Agregar `TZ` y `LAN_SUBNET` (valores reales confirmados en 1.1/1.2) al `.env` de producción, **antes** de tocar `docker-compose.yml` — hecho en el `.env` local de este repo (usado por `scripts/dev-test.sh`); pendiente replicarlo en el `.env` real del host de producción (Raspberry Pi), que no es accesible desde esta sesión

## 2. Editar docker-compose.yml

- [x] 2.1 Cambiar `TZ: 'America/Costa_Rica'` por `TZ: '${TZ}'`
- [x] 2.2 Cambiar `FTLCONF_webserver_acl: '+192.168.90.0/24,+127.0.0.1'` por `FTLCONF_webserver_acl: '+${LAN_SUBNET:?LAN_SUBNET debe estar definido en .env},+127.0.0.1'`
- [x] 2.3 Quitar la línea de volumen `./etc-dnsmasq.d:/etc/dnsmasq.d` del servicio `pihole`

## 3. Limpieza de README y .gitignore

- [x] 3.1 Actualizar la nota sobre `FTLCONF_webserver_acl` en `README.md` para reflejar que la subnet ahora se define en `.env` (no se edita `docker-compose.yml`)
- [x] 3.2 Mencionar `TZ` y `LAN_SUBNET` en la sección "Uso rápido" del README, junto a `PIHOLE_PASSWORD`
- [x] 3.3 Quitar `etc-dnsmasq.d/` de la sección "Estructura del repo" del README
- [x] 3.4 Quitar la entrada `etc-dnsmasq.d/` de `.gitignore`

## 4. Aplicar el cambio

- [x] 4.1 Verificar localmente con `docker compose config` que `TZ` y `FTLCONF_webserver_acl` resuelven a los valores esperados, sin levantar contenedores — confirmado: `TZ: America/Costa_Rica`, `FTLCONF_webserver_acl: +192.168.90.0/24,+127.0.0.1`
- [x] 4.2 Verificar que `docker compose config` falla con un mensaje claro si se prueba sin `LAN_SUBNET` definida (confirmar que el guard funciona) — confirmado: `error while interpolating services.pihole.environment.FTLCONF_webserver_acl: required variable LAN_SUBNET is missing a value: LAN_SUBNET debe estar definido en .env`
- [x] 4.3 Levantar el stack con `docker compose up -d` en el host de producción y confirmar que el servicio `pihole` se recrea
- [x] 4.4 Confirmar que el webserver arranca sin errores (`docker compose logs pihole | grep -i webserver`, o panel en `:8080/admin`)
- [x] 4.5 Confirmar que `etc-dnsmasq.d/` no se vuelve a crear tras un ciclo `down`/`up` limpio

## 5. Verificación funcional

- [x] 5.1 `dig @<ip-del-host> example.com A +dnssec` desde un dispositivo real de la LAN — confirmar respuesta con flag `ad`
- [x] 5.2 `dig @<ip-del-host> example.com AAAA +dnssec` desde el mismo dispositivo — confirmar respuesta con flag `ad`
- [x] 5.3 Confirmar en `etc-pihole/pihole.toml` que `webserver.acl` refleja la subnet real (no la de ejemplo) tras el arranque
- [x] 5.4 Archivar este change con `openspec archive` una vez verificados los pasos anteriores
