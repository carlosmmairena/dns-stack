## Why

`dnscrypt-proxy` no tiene healthcheck y `pihole` depende de él con la sintaxis corta de `depends_on` (`condition: service_started`, el default de Docker Compose) — que solo espera a que el contenedor arranque, no a que `dnscrypt-proxy` tenga un upstream realmente validado. Medido empíricamente en un arranque en frío: el puerto 5053 queda escuchando casi al instante, pero la selección de un servidor upstream vivo (fetch del listado de resolvers, prueba de certificados DNSCrypt) tarda hasta ~6 segundos más. Durante esa ventana, `pihole` puede recibir consultas y devolver SERVFAIL sin que nada en el stack lo sepa o lo prevenga.

## What Changes

- Agregar `drill` (paquete Alpine dedicado — no `ldns-tools`, que trae utilidades de ejemplo de ldns pero no `drill`) a la imagen de `dnscrypt-proxy`, con versión de paquete fijada explícitamente.
- Agregar un `healthcheck:` al servicio `dnscrypt-proxy` en `docker-compose.yml` que ejecute `drill -p 5053 example.com @127.0.0.1` — una resolución DNS real, no solo un chequeo de puerto abierto, para que la señal de salud refleje "¿puede resolver de verdad?".
- Cambiar el `depends_on` de `pihole` de la forma corta (`- dnscrypt-proxy`) a la forma larga con `condition: service_healthy`, para que `pihole` no arranque a aceptar tráfico DNS hasta que `dnscrypt-proxy` demuestre que puede resolver.
- Documentar en `docker-compose.yml`/`README.md` por qué se eligió `example.com` como dominio de prueba y la implicancia intencional de que el healthcheck depende de que haya conectividad a internet (correcto: si no hay upstream alcanzable, `dnscrypt-proxy` no debería reportarse sano).

## Capabilities

### New Capabilities
- `dnscrypt-proxy-healthcheck`: `dnscrypt-proxy` expone una señal de salud basada en resolución DNS real (no solo puerto abierto), y `pihole` no arranca a servir tráfico hasta que esa señal sea positiva.

### Modified Capabilities
(ninguna — no cambia el comportamiento de resolución/cifrado DNS en sí, solo el orden y las garantías de arranque)

## Impact

- `dnscrypt-proxy/Dockerfile`: se agrega `apk add drill` con versión de paquete fijada explícitamente (`drill=1.8.3-r2` para `alpine:3.20`); verificación vía la firma de paquetes propia de `apk` (Alpine firma su índice de repositorio y sus paquetes; `apk` valida automáticamente contra las claves ya embebidas en la imagen base) — mecanismo distinto al `minisign` manual usado para el binario de `dnscrypt-proxy` (que se descarga crudo desde GitHub Releases, fuera de cualquier gestor de paquetes), pero equivalente en garantía dado cómo se obtiene esta dependencia.
- Tamaño de imagen: +0.5 MB medido empíricamente (32 MB → 32.5 MB) con el paquete `drill` correcto — evaluado contra la alternativa `bind-tools`/`dig` (+9.3 MB, ~81 CVEs históricos en el tracker de Alpine vs. 6 de `ldns`) antes de esta decisión. (Una medición inicial con el paquete `ldns-tools`, incorrecto para este caso de uso, había dado +2.4 MB — corregido durante la implementación, ver `design.md`.)
- `docker-compose.yml`: `healthcheck:` nuevo en `dnscrypt-proxy`; `depends_on` de `pihole` pasa a forma larga con `condition: service_healthy`.
- `README.md`: nota sobre el dominio de prueba (`example.com`) y su implicancia de conectividad.
- Cadena de confianza DNS (device → Pi-hole → DNSCrypt-Proxy → upstream): sin cambios en ningún hop — este change es de orquestación/arranque, no de resolución ni cifrado.
- IPv4/IPv6: el healthcheck consulta solo IPv4 (`@127.0.0.1`), consistente con `dnscrypt-proxy.toml` (`ipv6_servers = false`). No se agrega ni quita soporte IPv6.
- No requiere cambios en `FTLCONF_webserver_acl` ni en la regla de firewall/DNAT pendiente — ninguno de los dos está relacionado con el arranque interno del stack.
