## 1. Dockerfile

- [x] 1.1 Agregar `RUN apk add --no-cache drill=1.8.3-r2` en la etapa final del `Dockerfile`, antes de `USER dnscrypt` — corregido durante la implementación: el paquete correcto es `drill`, no `ldns-tools` (ese no incluye el binario `drill`, confirmado con `apk info -L`); ver `design.md` Decisión 1
- [x] 1.2 Reconstruir la imagen y confirmar manualmente que `drill` funciona — confirmado: `docker run --rm --entrypoint drill dns-stack-dnscrypt-proxy -v` → `drill version 1.8.3 (ldns version 1.8.3)`. Tamaño de imagen: 32.5 MB (+0.5 MB sobre la base)

## 2. docker-compose.yml

- [x] 2.1 Agregar `healthcheck:` al servicio `dnscrypt-proxy` con `test: ["CMD", "drill", "-p", "5053", "example.com", "@127.0.0.1"]` — corregido durante la implementación: el orden `@servidor` primero (estilo `dig`) hace fallar a `drill` con "network error" aunque el puerto esté abierto; `@servidor` va al final. Ver `design.md` Decisión 2
- [x] 2.2 Fijar `interval: 10s`, `timeout: 5s`, `retries: 3`, `start_period: 15s`, documentando en un comentario el motivo (~6s medido de arranque en frío + margen)
- [x] 2.3 Cambiar `depends_on` de `pihole` de la forma corta (`- dnscrypt-proxy`) a la forma larga con `condition: service_healthy`

## 3. Documentación

- [x] 3.1 Documentar en `README.md` que el healthcheck de `dnscrypt-proxy` depende de conectividad real a internet (consulta `example.com`), y que por lo tanto `pihole` no arranca a servir tráfico si el host no tiene salida en ese momento

## 4. Verificación local

- [x] 4.1 Levantar el stack con el overlay de pruebas (`scripts/dev-test.sh up`) y observar con `docker inspect dnscrypt-proxy --format '{{json .State.Health}}'` la transición `starting` → `healthy` — confirmado: `"Status":"healthy"`, primer chequeo con `ExitCode: 0` y respuesta real de `example.com`
- [x] 4.2 Confirmar que el contenedor `pihole` no se crea/inicia hasta que `dnscrypt-proxy` reporta `healthy` — confirmado con timestamps: `dnscrypt-proxy` healthy a las 05:16:25.55, `pihole` `StartedAt` 05:16:26.05 (~0.5s después)
- [x] 4.3 `scripts/dev-test.sh dig example.com A` y `scripts/dev-test.sh dig example.com AAAA` — confirmar que la resolución dual-stack con `+dnssec` sigue funcionando sin cambios de comportamiento — confirmado, ambas con `RRSIG` presente

## 5. Aplicar en producción

- [x] 5.1 Desplegar en el host de producción (`docker compose up -d`) y confirmar la misma transición `starting` → `healthy` para `dnscrypt-proxy`
- [x] 5.2 Confirmar que `pihole` arrancó después de que `dnscrypt-proxy` quedó sano (revisar timestamps con `docker compose ps`/logs)
- [x] 5.3 `dig @<ip-del-host> example.com A +dnssec` y `dig @<ip-del-host> example.com AAAA +dnssec` desde un dispositivo real de la LAN — confirmar respuesta con flag `ad` en ambas familias
- [x] 5.4 Repetir el ciclo `down`/`up` un par de veces en el host real para confirmar que los valores de `interval`/`timeout`/`retries`/`start_period` de la tarea 2.2 son razonables en condiciones reales (no solo en el arranque local medido una vez)
- [x] 5.5 Archivar este change con `openspec archive` una vez verificados los pasos anteriores
