## ADDED Requirements

### Requirement: Capabilities Linux mínimas para el contenedor Pi-hole
El contenedor `pihole` SHALL NOT declarar Linux capabilities que no correspondan a una función activa del stack. En particular, `NET_ADMIN` SHALL NOT otorgarse mientras el stack no ofrezca DHCP ni Router Advertisements IPv6.

#### Scenario: Servicio Pi-hole sin DHCP activo
- **WHEN** el servicio `pihole` se define en `docker-compose.yml` y `dhcp.active` es `false`
- **THEN** el bloque `cap_add` del servicio `pihole` SHALL NOT incluir `NET_ADMIN`

#### Scenario: DHCP se habilita en el futuro
- **WHEN** un mantenedor activa DHCP para el servicio `pihole` en un change posterior
- **THEN** ese cambio SHALL agregar `NET_ADMIN` explícitamente al `cap_add` del servicio, documentando el motivo en el propio `docker-compose.yml`

### Requirement: Modo de escucha DNS correcto para topología de red bridge de Docker
El sistema SHALL configurar `dns.listeningMode` de Pi-hole en `ALL` cuando el servicio corre sobre una red bridge de Docker definida por el usuario con puertos DNS publicados hacia el host, para que las consultas de clientes LAN reales — cuya subnet no coincide con ninguna interfaz propia del contenedor — no sean rechazadas.

#### Scenario: Cliente LAN consulta vía el puerto publicado
- **WHEN** un dispositivo de la LAN, con una IP fuera de la subnet de la red Docker interna del stack, envía una consulta DNS al puerto 53 publicado del host
- **THEN** Pi-hole SHALL aceptar y resolver la consulta, sin rechazarla por no coincidir con una interfaz local del contenedor

#### Scenario: No existe NAT/port-forward hacia WAN
- **WHEN** `dns.listeningMode` está configurado en `ALL`
- **THEN** el despliegue SHALL depender de que el puerto DNS del host no tenga NAT/port-forward hacia WAN, documentado explícitamente como precondición de seguridad

### Requirement: Cliente NTP de Pi-hole desactivado por defecto
El sistema SHALL desactivar `ntp.sync.active` en el servicio `pihole`, delegando la sincronización de hora del host exclusivamente a un cliente NTP a nivel de sistema operativo del host.

#### Scenario: Arranque del stack sin cliente NTP propio
- **WHEN** el servicio `pihole` arranca con la configuración de este stack
- **THEN** `ntp.sync.active` SHALL ser `false` y Pi-hole SHALL NOT intentar ajustar el reloj del host

### Requirement: Servidor NTP de Pi-hole desactivado por defecto
El sistema SHALL desactivar `ntp.ipv4.active` y `ntp.ipv6.active` en el servicio `pihole`, ya que el stack SHALL NOT ofrecer servicio de hora a la LAN.

#### Scenario: Dispositivo de la LAN intenta usar Pi-hole como servidor NTP
- **WHEN** un dispositivo de la LAN envía una consulta NTP hacia la IP del host donde corre este stack
- **THEN** la consulta SHALL NOT recibir respuesta, ya que ni el servidor NTP de Pi-hole está activo ni el puerto `123/udp` está publicado
