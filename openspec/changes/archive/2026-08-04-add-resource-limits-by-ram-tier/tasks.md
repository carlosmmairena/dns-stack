## 1. Overlays de límites de recursos

- [x] 1.1 Crear `docker-compose.pi-2gb.yml` con `deploy.resources.limits` para `pihole` (memory: `512M`, cpus: `"1.5"`) y `dnscrypt-proxy` (memory: `128M`, cpus: `"0.5"`)
- [x] 1.2 Crear `docker-compose.pi-8gb.yml` con `deploy.resources.limits` para `pihole` (memory: `2048M`, cpus: `"3"`) y `dnscrypt-proxy` (memory: `256M`, cpus: `"1"`)
- [x] 1.3 Confirmar con `docker compose -f docker-compose.yml -f docker-compose.pi-2gb.yml config` (y el equivalente para `pi-8gb`) que los límites resuelven a los valores esperados, sin levantar nada

## 2. Documentación

- [x] 2.1 Actualizar `README.md`, sección "Uso rápido": agregar el paso opcional de sumar el overlay de tier según la RAM de la Raspberry Pi (`docker compose -f docker-compose.yml -f docker-compose.pi-<tier>gb.yml up -d`), con una tabla o nota de qué modelos de Pi corresponden a cada tier (2GB: Pi 3B+/Pi 4 2GB/Pi Zero 2 W; 8GB: Pi 4/5 8GB)
- [x] 2.2 Actualizar `README.md`, sección "Estructura del repo": listar `docker-compose.pi-2gb.yml` y `docker-compose.pi-8gb.yml` junto a `docker-compose.test.yml`
- [x] 2.3 Actualizar `CONTRIBUTING.md`, sección "Convenciones": documentar la convención de nombres de overlays de tier de recursos, reusando la justificación ya existente sobre por qué no se usa `docker-compose.override.yml`

## 3. Verificación

- [x] 3.1 Levantar el stack local de pruebas con el overlay de tier combinado (ej. `docker compose -f docker-compose.yml -f docker-compose.test.yml -f docker-compose.pi-2gb.yml up -d --build`) y confirmar que ambos contenedores arrancan y quedan `healthy`/`running`
- [x] 3.2 Con `docker stats` (o `docker compose ... top`), confirmar que los límites de memoria y CPU quedaron aplicados a `pihole` y `dnscrypt-proxy`
- [x] 3.3 Ejecutar `scripts/dev-test.sh dig example.com` y `scripts/dev-test.sh dig example.com AAAA`, confirmando resolución exitosa y flag `ad` (DNSSEC) en ambas familias — validar que los límites no rompen la resolución DNS normal
- [x] 3.4 Bajar el stack de pruebas (`scripts/dev-test.sh down`)
