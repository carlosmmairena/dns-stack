# DNS Stack - Pi-Hole + DNSCrypt-Proxy

Stack de DNS para la resolución DNS de una LAN.

## ¿Qué puede hacer?

- Filtra publicidad y dominios maliciosos en toda la LAN (Pi-hole).
- Cifra las consultas DNS salientes vía DNSCrypt hacia dos proveedores upstream independientes (Quad9 y CleanBrowsing Security), con failover automático entre ambos — nadie entre la red e internet ve en claro qué dominios se resuelven, y una interrupción de un proveedor no deja a la LAN sin DNS.
- Corre en Raspberry Pi (arm64 por defecto, arm de 32 bits ajustando `CPU_ARCH`).
- Alcance intencional: **solo DNS**. No ofrece DHCP ni NTP — ambos quedan a cargo de lo que ya exista en tu red (router y host). El contenedor `pihole` corre sin `NET_ADMIN` porque no la necesita para esto.

## Flujos

**Resolución normal (ambos resolvers disponibles):**
```
device → Pi-hole → dnscrypt-proxy ──┬─▶ quad9-dnscrypt-ip4-filter-pri (más rápido en wp2)
                                     └─▶ cleanbrowsing-security (candidato alterno, no consultado)
dnscrypt-proxy elige el servidor con mejor RTT/tasa de éxito dinámica (wp2) y responde a Pi-hole.
```

**Fallo de Quad9 (failover):**
```
device → Pi-hole → dnscrypt-proxy ──✕─▶ quad9-dnscrypt-ip4-filter-pri (timeout / sin respuesta)
                                     │
                                     └─▶ cleanbrowsing-security ──▶ responde
dnscrypt-proxy detecta la degradación (RTT/fallas) y desplaza el peso de selección
hacia cleanbrowsing-security en consultas subsiguientes — sin intervención manual,
sin caída de servicio para la LAN.
```

## Requisitos

- Docker y Docker Compose.
- Un host dentro de la LAN que pueda quedar fijo como servidor DNS (ideal: IP estática).
- El puerto 53 del host **NO** debe tener NAT/port-forward hacia WAN. `FTLCONF_dns_listeningMode` está en `ALL` (necesario para que Pi-hole acepte consultas de clientes LAN reales que le llegan vía el puerto publicado de Docker) — sin esta precondición, el resolver queda abierto a internet.

## Preparar el host (Debian/Raspberry Pi OS con systemd-resolved)

En hosts con `systemd-resolved` activo (Raspberry Pi OS y la mayoría de Debian/Ubuntu recientes), el puerto 53 ya está ocupado por su "stub listener" (`127.0.0.53`) antes de levantar este stack — `docker compose up -d` va a fallar con `address already in use` si no se libera primero. Confirmarlo con `sudo lsof -i :53` (va a aparecer un proceso `systemd-r` escuchando en `_localdnsstub:domain`/`_localdnsproxy:domain`).

Editar `/etc/systemd/resolved.conf` y, bajo `[Resolve]`, dejar:

```ini
[Resolve]
DNSStubListener=no
DNS=127.0.0.1 9.9.9.9
```

- `DNSStubListener=no`: libera el puerto 53 para que Pi-hole pueda publicarlo.
- `DNS=127.0.0.1 9.9.9.9`: hace que el propio host use Pi-hole como resolver primario (una vez levantado el stack) y Quad9 (`9.9.9.9`) como respaldo si Pi-hole no responde. `systemd-resolved` hace failover automático entre las entradas de `DNS=` (cada una lleva su propio contador de fallos) — no hace falta `FallbackDNS=` para esto, esa directiva solo se usa como último recurso cuando no hay ningún servidor DNS configurado en absoluto.

Aplicar y verificar:

```bash
sudo rm -f /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved
sudo lsof -i :53   # no debería mostrar nada — el puerto queda libre para Pi-hole
```

Recién ahí `docker compose up -d` puede publicar el puerto 53 sin conflicto.

## Uso rápido

```bash
cp .env.example .env
# editar PIHOLE_PASSWORD en .env
docker compose up -d
```

Después, apuntar el DNS del router (o de cada dispositivo) a la IP del host donde corre este stack.

Nota sobre `FTLCONF_webserver_acl`: ajustar `192.168.90.0/24` a la subnet real de la LAN si es distinta — no copiarlo literal sin verificar. Formato: lista separada por **comas** (`+192.168.90.0/24,+127.0.0.1`) — `webserver.acl` es un string, no un array; usar `;` como separador rompe el parser del ACL y tumba el webserver (`check_acl: subnet must be [+|-]IP-addr[/x]` en `webserver.log`).

## Verificación

```bash
dig @<ip-del-host> example.com +dnssec
```

Si responde con el flag `ad` (authenticated data), la validación DNSSEC está funcionando extremo a extremo.

## ¿Qué falta hacer?

Un punto muy importante de todo el stack, pendiente de implementar después de este servicio de DNS: la regla de firewall/DNAT para que ningún dispositivo pueda evadir el Pi-hole apuntando a otro DNS. Sin eso, todo este trabajo de cadena de confianza en el binario es sólido pero cubre una parte del problema — el resto de la red puede seguir resolviendo por fuera.

## Estructura del repo

```bash
dns-stack/
├── docker-compose.yml
├── docker-compose.test.yml   (overlay de pruebas locales, ver CONTRIBUTING.md)
├── .env.example
├── .gitignore
├── dnscrypt-proxy/
│   ├── Dockerfile
│   └── dnscrypt-proxy.toml
├── scripts/
│   └── dev-test.sh           (ver CONTRIBUTING.md)
├── etc-pihole/          (se crea sola al levantar pihole)
└── etc-dnsmasq.d/       (se crea sola al levantar pihole)
```

## Referencias

- [Pi-hole](https://github.com/pi-hole/pi-hole)
- [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)

## Licencia

GPLv3 — ver [LICENSE](LICENSE)
