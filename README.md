# DNS Stack - Pi-Hole + DNSCrypt-Proxy + Quad9 + Container

Stack de DNS para la resolución DNS de una LAN.

## ¿Qué puede hacer?

- Filtra publicidad y dominios maliciosos en toda la LAN (Pi-hole).
- Cifra las consultas DNS salientes hacia Quad9 vía DNSCrypt — nadie entre la red e internet ve en claro qué dominios se resuelven.
- Corre en Raspberry Pi (arm64 por defecto, arm de 32 bits ajustando `CPU_ARCH`).

Flujo:

```
device --> [Pi-hole] --> [DNSCrypt-Proxy] --> Quad9 (DNS encriptado) --> internet
```

## Requisitos

- Docker y Docker Compose.
- Un host dentro de la LAN que pueda quedar fijo como servidor DNS (ideal: IP estática).

## Uso rápido

```bash
cp .env.example .env
# editar PIHOLE_PASSWORD en .env
docker compose up -d
```

Después, apuntar el DNS del router (o de cada dispositivo) a la IP del host donde corre este stack.

Nota sobre `FTLCONF_webserver_acl`: ajustar `192.168.90.0/24` a la subnet real de la LAN si es distinta — no copiarlo literal sin verificar.

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
├── .env.example
├── .gitignore
├── dnscrypt-proxy/
│   ├── Dockerfile
│   └── dnscrypt-proxy.toml
├── etc-pihole/          (se crea sola al levantar pihole)
└── etc-dnsmasq.d/       (se crea sola al levantar pihole)
```

## Referencias

- [Pi-hole](https://github.com/pi-hole/pi-hole)
- [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)

## Licencia

GPLv3 — ver [LICENSE](LICENSE)
