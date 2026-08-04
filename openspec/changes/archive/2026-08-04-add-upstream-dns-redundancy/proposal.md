## Why

El stack depende hoy de un único resolver upstream (`quad9-dnscrypt-ip4-filter-pri`). Si Quad9 tiene una interrupción, un incidente o un bloqueo regional, toda la LAN pierde resolución DNS — el hardening de la cadena Pi-hole -> DNSCrypt-Proxy -> Quad9 es sólido pero no cubre disponibilidad. Se necesita un segundo proveedor DNSCrypt independiente, vetted con el mismo nivel de garantías, para eliminar ese punto único de confianza y disponibilidad.

## Goals

- Eliminar el punto único de disponibilidad/confianza del upstream DNS.
- Mantener el mismo nivel de garantías en el segundo proveedor: protocolo DNSCrypt, validación DNSSEC, política de no-log, filtrado de dominios maliciosos.
- Mantener el hop `dnscrypt-proxy -> upstream` homogéneo en protocolo (solo DNSCrypt, sin mezclar DoH) para no romper la cadena de confianza ya documentada.

## Non-Goals

- No resuelve el vector de bypass DNS vía IPv6 a nivel de LAN (SLAAC/RA/DHCPv6) — es un tema de firewall/red separado, ya documentado en `openspec/config.yaml`.
- No implementa Anonymized DNS relays — ni Quad9 ni CleanBrowsing Security son compatibles con anonimización según el catálogo de dnscrypt-resolvers.
- No cambia el filtrado de publicidad que hace Pi-hole ni el `FTLCONF_webserver_acl` del panel web.

## What Changes

- Agregar `cleanbrowsing-security` como segundo `server_name` en `dnscrypt-proxy.toml`, junto a `quad9-dnscrypt-ip4-filter-pri`, habilitando el balanceo/failover automático nativo de dnscrypt-proxy (`lb_strategy`, default `wp2`) entre ambos.
- Documentar en el `.toml` que `require_dnssec`, `require_nolog` y `require_nofilter` no filtran nada cuando `server_names` está fijado explícitamente (confirmado contra la documentación oficial de dnscrypt-proxy) — cada proveedor debe estar vetted manualmente, y dejar constancia de esa verificación como comentario.
- Actualizar toda referencia que describe el stack como dependiente únicamente de Quad9:
  - `README.md`: título, diagrama de flujo, bullet de capacidades.
  - `openspec/config.yaml`: bloque `context` (flujo, componentes, cadena de confianza por hop).
- Impacto en la cadena de confianza DNS (device -> Pi-hole -> DNSCrypt-Proxy -> Quad9/CleanBrowsing): el hop final pasa de "un upstream" a "dos upstreams independientes, mismo protocolo y garantías", sin cambiar los hops anteriores (LAN -> Pi-hole, Pi-hole -> dnscrypt-proxy).
- Soporte IPv4/IPv6: sin cambios — ambos `server_names` usados (`quad9-dnscrypt-ip4-filter-pri`, `cleanbrowsing-security`) son IPv4, consistente con `ipv4_servers=true` / `ipv6_servers=false` ya configurado. El vector de bypass IPv6 de LAN queda fuera de alcance (ver Non-Goals).
- No requiere ajustar reglas de firewall/DNAT ni `FTLCONF_webserver_acl` — el cambio es exclusivamente sobre el pool de resolvers upstream.
- No se agrega ninguna imagen o dependencia nueva al `docker-compose.yml`; `cleanbrowsing-security` se resuelve dinámicamente desde la misma fuente `public-resolvers.md` ya configurada y verificada por minisign en `dnscrypt-proxy.toml` — no aplica fijar versión/firma adicional.

## Capabilities

### New Capabilities
- `dnscrypt-upstream-resolution`: define el requisito de resolver DNS a través de múltiples resolvers DNSCrypt upstream independientes y vetted (protocolo DNSCrypt, DNSSEC, no-log, filtrado de malware), con failover automático entre ellos.

### Modified Capabilities
(ninguna — no hay specs previas en `openspec/specs/`)

## Impact

- **Archivos afectados**: `dnscrypt-proxy/dnscrypt-proxy.toml` (server_names + comentarios), `README.md` (título, flujo, capacidades), `openspec/config.yaml` (context).
- **Sistemas**: solo el contenedor `dnscrypt-proxy`; Pi-hole y la red `pihole_net` no cambian.
- **Dependencias**: ninguna nueva; se usa la misma fuente de resolvers (`public-resolvers.md`, verificada por minisign) ya presente en el `.toml`.
- **Verificación manual de proveedores** (ya realizada durante la exploración de este change, no requiere repetirse): DNSSEC y no-log de CleanBrowsing Security confirmados contra su documentación técnica (`cleanbrowsing.org/help/docs/...dnssec`) y política de privacidad (`cleanbrowsing.org/privacy`), no solo su página de producto.
