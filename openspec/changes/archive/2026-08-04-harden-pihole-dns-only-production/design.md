## Context

`docker-compose.yml` configura hoy el servicio `pihole` con `cap_add: NET_ADMIN` y `FTLCONF_dns_listeningMode: 'LOCAL'`, y `etc-pihole/pihole.toml` trae `ntp.sync.active`, `ntp.ipv4.active` y `ntp.ipv6.active` en `true` (defaults de Pi-hole, nunca desactivados explícitamente). Ninguno de los cuatro corresponde al alcance confirmado del stack: solo DNS, sin DHCP.

`pihole` corre sobre la red bridge definida por el usuario `pihole_net` (172.20.0.0/24, IP fija 172.20.0.3), con `53:53/tcp`, `53:53/udp` y `8080:80/tcp` publicados hacia el host. No hay NAT/port-forward del puerto 53 hacia WAN — el host solo es alcanzable desde la LAN.

## Goals / Non-Goals

**Goals:**
- Minimizar las Linux capabilities del contenedor `pihole` a solo las que el stack usa de verdad.
- Que el `listeningMode` de FTL acepte correctamente consultas DNS de clientes reales de la LAN llegando vía el puerto publicado, sin depender de un comportamiento no verificado.
- Apagar explícitamente NTP cliente y servidor, ya que ninguno fue pedido y ambos están hoy mal cableados (falta `SYS_TIME` para uno, falta el puerto publicado para el otro).
- Aplicar los cuatro cambios de forma reproducible vía `docker-compose.yml` (env vars `FTLCONF_*` y `cap_add`), consistente con el patrón ya usado en este repo — no editar `pihole.toml` a mano, ya que ese archivo no se versiona y se regenera en cada arranque.

**Non-Goals:**
- Implementar la regla de firewall/DNAT que fuerza a todos los dispositivos de la LAN a usar Pi-hole (pendiente documentado en el README, change separado).
- Cualquier soporte o bloqueo adicional de IPv6 más allá de apagar `ntp.ipv6.active`.
- Reintroducir DHCP o Router Advertisements.
- Cambiar el modo de red del stack (se mantiene `pihole_net`, una bridge definida por el usuario; no se pasa a `network_mode: host`).

## Decisions

### 1. Quitar `cap_add: NET_ADMIN`
La documentación oficial de Pi-hole confirma que `NET_ADMIN` solo es necesaria para respuestas unicast de DHCP y Router Advertisements IPv6 — ninguno de los dos está en uso. Se descarta la alternativa de "dejarla por las dudas": una capability sin función activa es superficie de ataque de más si el contenedor `pihole` (el único de los dos servicios expuesto a la LAN) llegara a comprometerse. Si en el futuro se activa DHCP, reintroducir la capability es un cambio de una línea.

### 2. `FTLCONF_dns_listeningMode`: `'LOCAL'` → `'ALL'`
El modo `LOCAL` se traduce en la directiva `local-service` de dnsmasq, que acepta una consulta solo si la IP origen pertenece a una subnet para la que el proceso tiene una interfaz propia. Dentro del contenedor, las únicas interfaces son `172.20.0.0/24` (la bridge `pihole_net`) y loopback — la subnet real de un cliente LAN nunca coincide, porque el paquete llega vía DNAT de Docker conservando la IP origen del cliente pero entrando por `eth0`. La propia documentación de Pi-hole, en su página de problemas comunes, indica que los despliegues Docker en red bridge con puertos publicados requieren `ALL`; todos los ejemplos oficiales de `docker-compose.yml` para Docker usan `ALL`, nunca `LOCAL`.

Alternativa considerada — mantener `LOCAL` y pasar a `network_mode: host`: descartada. Habría resuelto el problema de raíz (FTL vería la interfaz real de la LAN), pero exige rediseñar toda la topología actual (pihole_net, IPs fijas, el aislamiento de dnscrypt-proxy sin puerto publicado) por un beneficio que `ALL` ya cubre con un cambio de una línea.

`ALL` amplía qué orígenes acepta el contenedor en el puerto DNS. El riesgo de "resolver abierto" que señala la documentación de Pi-hole aplica solo si el puerto 53 fuera alcanzable desde WAN, lo cual no es el caso mientras no exista NAT/port-forward hacia afuera — precondición que este change no verifica automáticamente, la declara como dependencia explícita.

### 3. Apagar NTP cliente (`ntp.sync.active = false`)
Un contenedor no tiene reloj propio: comparte el reloj del kernel del host (no hay namespace de reloj activo por defecto). `ntp.sync.active = true` no ajusta un reloj "interno" del contenedor, ajusta el reloj del Raspberry Pi. Raspberry Pi OS ya trae su propio cliente NTP (`systemd-timesyncd`) por defecto. Mantener el cliente NTP de Pi-hole activo significaría, además, tener que agregar `SYS_TIME` — otra capability sin necesidad real, para una función redundante con lo que el host ya hace.

Alternativa considerada — agregar `SYS_TIME` y mantener el cliente NTP activo: descartada por la razón anterior; se documenta como precondición que el host debe tener su propio sync de hora funcionando (ver Riesgos).

### 4. Apagar NTP servidor (`ntp.ipv4.active = false`, `ntp.ipv6.active = false`)
Nunca fue solicitado y hoy es inalcanzable — `123/udp` no está publicado en `docker-compose.yml`. Apagarlo hace que la configuración declarada coincida con el comportamiento real, y con el alcance "solo DNS" confirmado para este stack.

### Mecanismo de aplicación
Los cuatro cambios se implementan en `docker-compose.yml`: `cap_add` se edita directamente (no es una opción de FTL); `listeningMode` y los tres flags de NTP se fijan vía variables `FTLCONF_dns_listeningMode`, `FTLCONF_ntp_sync_active`, `FTLCONF_ntp_ipv4_active` y `FTLCONF_ntp_ipv6_active`, siguiendo el mismo patrón ya usado para `dns.upstreams`, `dns.dnssec` y `webserver.acl`. Al fijarlas por env var, esas cuatro opciones quedan de solo lectura en la UI/CLI de Pi-hole hasta que la variable se quite del compose — comportamiento ya asumido y documentado para el resto de las opciones de este stack.

## Risks / Trade-offs

- **[Riesgo]** `listeningMode = ALL` sin la regla de firewall/DNAT pendiente deja el puerto 53 aceptando cualquier origen que le llegue, no solo la LAN → **Mitigación**: depende explícitamente de que no exista NAT/port-forward hacia WAN (confirmado para este deployment); se documenta la dependencia en el README y se refuerza la prioridad del change de firewall/DNAT ya señalado como pendiente crítico.
- **[Riesgo]** Apagar el cliente NTP de Pi-hole asume que el host ya sincroniza su propio reloj; si no lo hace, el drift de reloj puede afectar la validación DNSSEC (sensible al tiempo) → **Mitigación**: se documenta como precondición a verificar (`timedatectl` en el Raspberry Pi) antes de aplicar este change.
- **[Riesgo]** Quitar `NET_ADMIN` bloquearía un futuro uso de DHCP/RA si el alcance del stack cambia → **Mitigación**: decisión intencional acorde al alcance actual; revertir es un cambio de una línea, documentado con referencia a este change.
- **[Trade-off]** Los cuatro cambios requieren recrear el contenedor `pihole` (no alcanza con un restart, ya que `cap_add` se fija en la creación del contenedor) → aceptable, ya cubierto por el flujo normal de `docker compose up -d` tras editar `docker-compose.yml`.

## Migration Plan

1. Editar `docker-compose.yml`: quitar `cap_add: NET_ADMIN`, cambiar `FTLCONF_dns_listeningMode` a `'ALL'`, agregar `FTLCONF_ntp_sync_active: 'false'`, `FTLCONF_ntp_ipv4_active: 'false'`, `FTLCONF_ntp_ipv6_active: 'false'`.
2. `docker compose up -d` — recrea el servicio `pihole` (cambio de `cap_add` y de env vars fuerza recreación).
3. Verificar en el contenedor recreado que `pihole.toml` refleja los nuevos valores como `### CHANGED (env)`.
4. Verificar resolución DNS desde un dispositivo real de la LAN (no desde el host de Docker) contra la IP del host — valida que `listeningMode = ALL` efectivamente resuelve el problema de origen descrito en la Decisión 2.
5. Rollback: revertir las cuatro líneas en `docker-compose.yml` y `docker compose up -d` nuevamente. `etc-pihole/` (gravity.db, listas, etc.) no se ve afectado por este change — el rollback es de bajo riesgo.

## Open Questions

- ¿El Raspberry Pi objetivo ya tiene un cliente NTP propio confirmado y funcionando (`timedatectl status`)? Es la precondición del punto 3 de Decisiones.
- ¿Hay algún plan a futuro de exponer el puerto 53 hacia WAN (ej. para resolver DNS mientras se está fuera de la LAN)? Si la respuesta cambia de "no" a "sí" en algún momento, `listeningMode = ALL` debe revisarse junto con la regla de firewall/DNAT pendiente.
