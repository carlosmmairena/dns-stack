## 1. Precondiciones

- [x] 1.1 Confirmar que el host Raspberry Pi tiene un cliente NTP propio activo (`timedatectl status`) antes de apagar el cliente NTP de Pi-hole
- [x] 1.2 Confirmar que no existe NAT/port-forward del puerto 53 hacia WAN en el router de la LAN, antes de cambiar `listeningMode` a `ALL` — confirmado por el usuario: solo LAN, sin NAT/port-forward hacia WAN

## 2. Editar docker-compose.yml

- [x] 2.1 Quitar `cap_add: NET_ADMIN` del servicio `pihole`
- [x] 2.2 Cambiar `FTLCONF_dns_listeningMode` de `'LOCAL'` a `'ALL'`
- [x] 2.3 Agregar `FTLCONF_ntp_sync_active: 'false'`
- [x] 2.4 Agregar `FTLCONF_ntp_ipv4_active: 'false'`
- [x] 2.5 Agregar `FTLCONF_ntp_ipv6_active: 'false'`

## 3. Aplicar el cambio

- [x] 3.1 Levantar el stack con `docker compose up -d` **en el host de producción (Raspberry Pi)** y confirmar que el servicio `pihole` se recrea (no solo se reinicia) — pendiente, requiere el host real
- [x] 3.2 Inspeccionar `etc-pihole/pihole.toml` y confirmar que `dns.listeningMode`, `ntp.sync.active`, `ntp.ipv4.active` y `ntp.ipv6.active` reflejan los nuevos valores marcados `### CHANGED (env)` — validado localmente con el overlay de pruebas (`scripts/dev-test.sh up`): `listeningMode = "ALL" ### CHANGED (env), default = "LOCAL"`, y las 4 claves listadas en "forced through environment". Pendiente re-confirmar en el host de producción tras 3.1.
- [x] 3.3 Confirmar con `docker inspect pihole` que `NET_ADMIN` ya no aparece en las capabilities efectivas del contenedor — validado localmente: `HostConfig.CapAdd` es `[]`. Pendiente re-confirmar en el host de producción tras 3.1.

## 4. Verificación funcional

- [x] 4.1 Desde un dispositivo real de la LAN (no desde el host de Docker), ejecutar `dig @<ip-del-host> example.com A +dnssec` y confirmar respuesta con flag `ad` — pendiente, requiere el host de producción y un dispositivo LAN real. (Smoke test local vía `scripts/dev-test.sh dig example.com A` ya confirmó `flags: qr rd ra ad` con los 4 cambios aplicados, pero ese camino no reproduce el escenario DNAT/subnet-externa que motiva el cambio de `listeningMode` — no reemplaza esta verificación)
- [x] 4.2 Desde el mismo dispositivo, ejecutar `dig @<ip-del-host> example.com AAAA +dnssec` y confirmar respuesta con flag `ad` — pendiente, mismo motivo que 4.1. (Smoke test local ya confirmó `ad` en AAAA también)
- [x] 4.3 Confirmar en los logs de Pi-hole (o en el panel web) que las consultas del paso 4.1/4.2 se registraron como resueltas, no como rechazadas/refusadas
- [x] 4.4 Confirmar que el contenedor `pihole` no intenta ninguna operación de ajuste de hora en sus logs tras la recreación (cliente NTP apagado)

## 5. Documentación

- [x] 5.1 Actualizar `README.md`: declarar explícitamente el alcance "solo DNS, sin DHCP, sin NTP" y la precondición de que no exista NAT/port-forward de 53 hacia WAN como base de seguridad de `listeningMode = ALL`
- [ ] 5.2 Archivar este change con `openspec archive` una vez verificados los pasos de la sección 4
