## Context

`dnscrypt-proxy.toml` fija hoy `server_names = ['quad9-dnscrypt-ip4-filter-pri']`. Es una única entrada explícita, lo que (confirmado contra la documentación oficial de dnscrypt-proxy) hace que `require_dnssec`, `require_nolog` y `require_nofilter` no filtren nada — esos flags solo aplican cuando `server_names` está vacío y dnscrypt-proxy selecciona automáticamente del catálogo completo. Con una lista explícita, el servidor se usa "regardless of other filter settings"; la responsabilidad de que el resolver cumpla DNSSEC/no-log recae en quien lo eligió, no en el `.toml`.

Si Quad9 tiene una interrupción, un incidente de infraestructura o un bloqueo regional, no hay ningún mecanismo de respaldo — toda la LAN pierde DNS.

## Goals / Non-Goals

**Goals:**
- Que `dnscrypt-proxy` tenga dos resolvers upstream DNSCrypt independientes, cada uno vetted manualmente con el mismo nivel de garantías (DNSSEC, no-log, filtrado de malware).
- Aprovechar el balanceo/failover nativo de dnscrypt-proxy (`lb_strategy`) en vez de construir lógica de salud/failover propia.
- Dejar registrado en el propio `.toml` que la validación de `require_*` es inerte con `server_names` explícito, para que quien edite el archivo después no asuma una protección que no existe.

**Non-Goals:**
- No se implementa Anonymized DNS (ninguno de los dos proveedores es compatible).
- No se resuelve el bypass DNS vía IPv6 en la LAN.
- No se modifica el filtrado de Pi-hole ni el ACL del panel web.

## Decisions

**1. Segundo proveedor: CleanBrowsing Security, no AdGuard ni Cloudflare Security.**
Se evaluaron tres candidatos durante la exploración previa a este change:
- *AdGuard DNS* (`adguard-dns`): protocolo DNSCrypt correcto, pero DNSSEC y política de logs no están declarados ni en el catálogo de dnscrypt-resolvers ni en su página pública (`adguard-dns.io/en/public-dns.html`). Descartado por falta de verificación, no por un defecto conocido.
- *Cloudflare Security* (`cloudflare-security`): descartado por dos razones — (a) es DoH, no DNSCrypt (confirmado decodificando el byte de protocolo del stamp: `0x02`), lo que mezclaría protocolos en el hop upstream y rompería la homogeneidad documentada en la cadena de confianza; (b) mismo vacío de verificación de DNSSEC/no-log que AdGuard en su página oficial.
- *CleanBrowsing Security* (`cleanbrowsing-security`): protocolo DNSCrypt confirmado (`0x01`), alcance equivalente a Quad9 (phishing/spam/malware/dominios maliciosos, sin filtrar contenido adulto). DNSSEC confirmado en `cleanbrowsing.org/help/docs/common-dns-resolution-with-resolvers-dnssec/` y no-log (para el resolver público/gratuito) confirmado en `cleanbrowsing.org/privacy`. Único candidato con ambas garantías verificadas contra fuente primaria, no solo la landing de producto.

**2. Failover vía `lb_strategy` nativo, no un mecanismo custom.**
dnscrypt-proxy ya balancea entre los `server_names` configurados usando una lista dinámica de "los más rápidos disponibles" (default `wp2`: selección ponderada entre 2 candidatos según RTT y tasa de éxito). Construir health-checks o failover propio sería reinventar algo que la herramienta ya resuelve — se usa el default sin overrides.

**3. Documentar, no corregir, el comportamiento de `require_*` con lista explícita.**
La alternativa sería vaciar `server_names` y depender de `require_dnssec`/`require_nolog`/`require_nofilter` para auto-seleccionar del catálogo completo. Se descarta porque el proyecto depende de curar manualmente proveedores específicos (verificados contra fuentes primarias) — la auto-selección entregaría el control a criterios del catálogo público, que ya vimos que no siempre están completos o son verificables. Se opta por dejar la lista explícita y documentar la limitación con un comentario en el `.toml`.

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

## Risks / Trade-offs

- **[Riesgo]** CleanBrowsing retiene indefinidamente datos agregados/anonimizados (no PII) con fines de seguridad/investigación → **Mitigación**: aceptado como trade-off estándar de la industria; el mismo nivel de confianza que ya se le da a la declaración de Quad9 ("no log client IP addresses") sin auditoría independiente.
- **[Riesgo]** Dos entidades (Quad9 y CleanBrowsing) ahora pueden ver la IP pública de la LAN en vez de una sola → **Mitigación**: ninguna de las dos es compatible con Anonymized DNS, así que esto queda como limitación conocida y no como regresión — el estado actual (Quad9 solo) tiene el mismo problema con una sola entidad.
- **[Riesgo]** `wp2` puede seguir enviando algo de tráfico a un resolver degradado (lento pero no completamente caído) → **Mitigación**: es el comportamiento esperado del algoritmo ponderado; no requiere acción, se degrada gradualmente en vez de binario.
- **[Riesgo]** El vector de bypass IPv6 de LAN sigue sin resolverse → **Mitigación**: fuera de alcance de este change, ya documentado como pendiente separado en `openspec/config.yaml`.

## Migration Plan

1. Editar `dnscrypt-proxy/dnscrypt-proxy.toml`: `server_names = ['quad9-dnscrypt-ip4-filter-pri', 'cleanbrowsing-security']` + comentario documentando que `require_*` es inerte con lista explícita y que ambos proveedores fueron vetted manualmente.
2. `docker compose restart dnscrypt-proxy` (el `.toml` es un bind mount de solo lectura, no requiere rebuild de imagen).
3. Verificar con `dig @<ip-del-host> example.com +dnssec` que la resolución y el flag `ad` siguen funcionando.
4. Actualizar `README.md` (título, diagrama de flujo, bullet de capacidades) y `openspec/config.yaml` (context: flujo, componentes, cadena de confianza) para reflejar los dos proveedores.
5. **Rollback**: revertir `server_names` a la entrada única de Quad9 y reiniciar el contenedor — cambio de configuración sin estado, trivialmente reversible.

## Open Questions

- ¿Vale la pena explorar a futuro un tercer proveedor compatible con Anonymized DNS, aceptando que ni Quad9 ni CleanBrowsing lo son hoy?
- ¿El vector de bypass IPv6 de LAN se aborda como change separado próximamente, o queda documentado sin fecha?
