## 1. Configuración de dnscrypt-proxy

- [x] 1.1 Agregar `cleanbrowsing-security` a `server_names` en `dnscrypt-proxy.toml`, junto a `quad9-dnscrypt-ip4-filter-pri`
- [x] 1.2 Agregar comentario en el `.toml` documentando que `require_dnssec`/`require_nolog`/`require_nofilter` no filtran nada con `server_names` explícito, y que ambos proveedores fueron vetted manualmente (DNSSEC + no-log confirmados contra fuente primaria, no solo el catálogo)
- [x] 1.3 Reiniciar el contenedor (`docker compose restart dnscrypt-proxy`) para aplicar el nuevo `.toml` — no requiere rebuild de imagen

## 2. Verificación

- [x] 2.1 Confirmar en los logs de `dnscrypt-proxy` que ambos resolvers (`quad9-dnscrypt-ip4-filter-pri`, `cleanbrowsing-security`) se cargaron correctamente
- [x] 2.2 Ejecutar `dig @<ip-del-host> example.com +dnssec` (A) y confirmar resolución correcta y flag `ad`
- [x] 2.3 Ejecutar `dig @<ip-del-host> example.com AAAA +dnssec` y confirmar resolución correcta y flag `ad` (verificación dual-stack; Pi-hole debe responder consultas AAAA sin error aunque el upstream sea IPv4-only)
- [x] 2.4 Simular la caída del resolver primario y confirmar que dnscrypt-proxy sigue resolviendo vía CleanBrowsing Security sin intervención manual

## 3. Actualizar documentación

- [x] 3.1 Actualizar `README.md`: título, diagrama de flujo y bullet de capacidades, para que no describan a Quad9 como único proveedor
- [x] 3.2 Actualizar `openspec/config.yaml`: bloque `context` (flujo, componentes, cadena de confianza por hop) para reflejar los dos proveedores upstream
- [x] 3.3 Revisar (`grep -rni "quad9" .`) que no quede ninguna mención residual que implique un único proveedor
