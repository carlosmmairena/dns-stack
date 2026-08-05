## Why

El stack quedó confirmado como DNS-only (sin DHCP), pero el `docker-compose.yml` y `pihole.toml` actuales cargan configuración que no corresponde a ese alcance: una capability (`NET_ADMIN`) que solo hace falta para DHCP/Router Advertisements, dos funciones NTP (cliente y servidor) que nunca se pidieron y están a medio cablear (falta `SYS_TIME` para el cliente, falta publicar `123/udp` para el servidor), y un `listeningMode` (`LOCAL`) que, según la documentación oficial de Pi-hole ("Common Issues"), es incorrecto para un despliegue en red bridge de Docker con puertos publicados — puede rechazar en silencio consultas de clientes reales de la LAN porque su subnet no coincide con ninguna interfaz propia del contenedor. Este change cierra esas cuatro brechas para que el compose de producción refleje exactamente "solo DNS" y nada más.

## What Changes

- Quitar `cap_add: NET_ADMIN` del servicio `pihole` en `docker-compose.yml` — no requerido sin DHCP ni Router Advertisements IPv6.
- Cambiar `FTLCONF_dns_listeningMode` de `'LOCAL'` a `'ALL'` en `docker-compose.yml`, alineado con la recomendación oficial de Pi-hole para topologías de red bridge de Docker con puertos publicados. Esto asume — y depende de — que el puerto 53 del host nunca tiene NAT/port-forward hacia WAN (solo alcanzable desde la LAN).
- Desactivar el cliente NTP de Pi-hole (`ntp.sync.active = false`) — se deja la sincronización de hora del Raspberry Pi a cargo del propio host (ej. `systemd-timesyncd`), evitando dos sincronizadores de reloj compitiendo sobre el mismo reloj de kernel compartido entre host y contenedor.
- Desactivar el servidor NTP de Pi-hole (`ntp.ipv4.active = false`, `ntp.ipv6.active = false`) — funcionalidad que nunca se pidió y que además era inalcanzable (`123/udp` nunca estuvo publicado en el compose).
- Documentar en `docker-compose.yml` el porqué de los cambios de `listeningMode` y NTP, y en `README.md` el alcance general del stack (incluyendo por qué el servicio `pihole` corre sin `NET_ADMIN`), para que un futuro mantenedor no revierta estos cambios por error asumiendo que hacen falta.

## Capabilities

### New Capabilities
- `pihole-dns-only-deployment`: alcance, minimización de capabilities Linux, y modo de escucha DNS correctos para un despliegue de Pi-hole cuya única función es resolución DNS (sin DHCP, sin NTP) sobre una red bridge de Docker con puertos publicados solo hacia la LAN.

### Modified Capabilities
(ninguna — `dnscrypt-upstream-resolution` y `dev-test-workflow` no cambian de comportamiento con este change)

## Impact

- `docker-compose.yml`: se quita `cap_add: NET_ADMIN` del servicio `pihole`; se cambia el valor de `FTLCONF_dns_listeningMode`; se agregan variables `FTLCONF_ntp_*` (o equivalente) para desactivar NTP cliente/servidor de forma reproducible vía env, consistente con el resto de la configuración de este repo.
- `README.md`: se documenta el nuevo alcance explícito ("solo DNS, sin DHCP, sin NTP") y la dependencia de que no exista NAT/port-forward de 53 hacia WAN como precondición de seguridad para `listeningMode = ALL`.
- `etc-pihole/pihole.toml`: se regenera con los nuevos valores en el próximo arranque del contenedor (archivo no versionado, gitignored).
- Cadena de confianza DNS (device → Pi-hole → DNSCrypt-Proxy → upstream): sin cambios en los hops de DNSCrypt-Proxy/upstream; el único hop afectado es device → Pi-hole, donde se amplía qué orígenes acepta el contenedor (`ALL` en vez de `LOCAL`), mitigado por la ausencia de exposición WAN.
- IPv4/IPv6: sin cambios de soporte DNS en ninguna familia; el único efecto IPv6 es apagar el servidor NTP IPv6 (`ntp.ipv6.active`), que ya era inalcanzable.
- No se agregan imágenes ni dependencias nuevas — no aplica fijar versión/verificación adicional.
- No requiere cambios en `FTLCONF_webserver_acl` (panel web sigue restringido a la LAN, sin relación con `listeningMode` de DNS).
- El pendiente de firewall/DNAT documentado en el README (evitar que dispositivos evadan Pi-hole apuntando a otro DNS) sigue fuera de alcance de este change, pero pasa a ser más relevante: `listeningMode = ALL` depende de que ese perímetro (ausencia de NAT hacia WAN) se mantenga.
