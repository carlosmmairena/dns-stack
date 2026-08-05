## Context

Ninguno de los dos servicios de `docker-compose.yml` (`pihole`, `dnscrypt-proxy`) declara límite de memoria ni de CPU. Ambos ya tienen `restart: unless-stopped`, lo que importa para esta decisión: un OOM-kill causado por un límite de memoria no deja el servicio caído, Docker lo reinicia solo.

Datos que fundamentan por qué hace falta un techo, y de qué magnitud:
- La documentación oficial de Pi-hole (`docs/main/prerequisites.md`, vía Context7) publica un mínimo de **512MB de RAM** para que Pi-hole funcione — es el piso de referencia para el tier más chico, no un número arbitrario.
- Los propios mantenedores de Pi-hole FTL documentan memory leaks conocidos (`docs/ftldns/valgrind.md`) en `FTL_reload_all_domainlists` y `gravityDB_open` — confirma que el escenario "una fuga eventualmente agota la RAM del host" no es hipotético.
- `dnscrypt-proxy` tiene footprint chico y estable: `cache_size = 4096` entradas en `dnscrypt-proxy.toml`, sin historial ni base de datos propia — su consumo no escala con la RAM del host de la misma forma que Pi-hole (FTL guarda historial de queries, gravity list, sesiones web).
- Confirmado contra el código fuente de `docker/compose` (`pkg/compose/create.go`, `getDeployResources`): `deploy.resources.limits` (cpus, memory) se aplica en `docker compose up` standalone, fuera de Swarm. Solo `resources.reservations.cpus` es swarm-only — no aplica acá, este change solo usa `limits`.
- El stack está pensado para Raspberry Pi (`docker-compose.yml` ya tiene `CPU_ARCH` como build arg); los modelos relevantes van de 2GB (Pi 3B+, Pi 4 2GB, Pi Zero 2 W) a 8GB (Pi 4/5 8GB) de RAM, todos con 4 núcleos de CPU.

## Goals / Non-Goals

**Goals:**
- Techo de memoria y CPU para `pihole` y `dnscrypt-proxy`, seleccionable por overlay según la RAM real de la Raspberry Pi.
- Mantener `docker-compose.yml` base sin límites — la forma "hay un techo, pero cuál depende de la instalación" vive en qué overlay elige el operador, no en una variable oculta.
- Reusar el patrón ya validado en el repo (`docker-compose.test.yml` + `-f` explícito) en vez de introducir un mecanismo nuevo.

**Non-Goals:**
- No se detecta automáticamente la RAM del host ni se valida en runtime que el tier elegido coincide con el hardware real — la elección del overlay correcto es responsabilidad documentada del operador (ver Open Questions).
- No se agrega un tier intermedio (ej. 4GB) en este change — el patrón permite agregarlo después como un archivo más, sin romper nada.
- No se ajustan `pids-limit`, `memswap_limit` ni ninguna otra dimensión de `deploy.resources` más allá de `memory`/`cpus` — no hay evidencia de que hagan falta hoy.

## Decisions

### 1. Dos overlays nuevos (`docker-compose.pi-2gb.yml`, `docker-compose.pi-8gb.yml`), no variables `.env`

Mismo mecanismo que `docker-compose.test.yml`: overlay combinado con `-f` explícito, nunca `docker-compose.override.yml` (se auto-mergea con cualquier `docker compose` suelto — en la Pi real de producción aplicaría límites sin que nadie lo pida, igual que el riesgo ya documentado en `CONTRIBUTING.md` para el overlay de test).

Alternativa considerada — variables `.env` (`PIHOLE_MEM_LIMIT`, `PIHOLE_CPUS`, etc.), mismo patrón que `TZ`/`LAN_SUBNET`/`PIHOLE_PASSWORD`: descartada explícitamente por el usuario ("menos piezas que ajustar"). Con overlays, elegir el tier es un solo flag en el comando de arranque, no cuatro-seis variables a copiar/ajustar en `.env` por servicio.

### 2. Nombres de archivo: `docker-compose.pi-2gb.yml` / `docker-compose.pi-8gb.yml`

El nombre codifica directamente la RAM total del host, no una etiqueta abstracta (`-small`/`-large`) — el operador solo necesita saber cuánta RAM tiene su Raspberry Pi para elegir el archivo correcto, sin tener que interpretar qué tier corresponde a qué hardware.

### 3. Valores de límites por tier

| | `pi-2gb` | `pi-8gb` |
|---|---|---|
| `pihole` memory | `512M` | `2048M` |
| `pihole` cpus | `"1.5"` | `"3"` |
| `dnscrypt-proxy` memory | `128M` | `256M` |
| `dnscrypt-proxy` cpus | `"0.5"` | `"1"` |

- `pihole` en `pi-2gb` usa el piso publicado por la propia documentación de Pi-hole (512MB) — es el mínimo con el que Pi-hole declara que funciona, no un valor recortado por debajo de lo soportado.
- `dnscrypt-proxy` no escala tan agresivamente entre tiers porque su cache está acotada por configuración (`cache_size = 4096`), no por RAM disponible — su consumo real no crece mucho aunque el host tenga más memoria.
- `cpus` deja siempre al menos ~0.5-1 núcleo libre de los 4 típicos en los modelos de Pi relevantes, para el host y para el otro contenedor, en ambos tiers.

Alternativa considerada — un único set de límites "conservador" para todos los tamaños de Pi: descartada porque un límite lo bastante bajo para ser seguro en una Pi de 2GB desperdicia la mayoría de la RAM disponible en una de 8GB, y un límite cómodo para 8GB puede directamente no dejar arrancar Pi-hole en una de 2GB.

### 4. Formato: `deploy.resources.limits`, no `mem_limit`/`cpus` legacy

Se usa la sintaxis moderna del Compose Spec (`deploy.resources.limits.memory`/`.cpus`) en vez de las claves legacy de nivel de servicio (`mem_limit`, `cpus`) — ambas funcionan hoy con `docker compose up` standalone, pero `deploy.resources` es la forma no deprecada y la misma que ya usan las guías oficiales de Docker Compose.

## Risks / Trade-offs

- **[Riesgo]** El operador levanta el stack con el overlay equivocado para su hardware real (ej. `pi-8gb` en una Pi de 2GB) → **Mitigación**: nombres de archivo explícitos por RAM (no símbolos abstractos) + tabla de modelos de Pi por RAM documentada en `README.md`. No hay detección automática — Compose no puede leer la RAM del host y branchear solo.
- **[Riesgo]** El límite de `pihole` en `pi-2gb` (512M) resulta demasiado ajustado en operación normal (sin fuga) y el contenedor se reinicia repetidamente en vez de resolver el problema → **Mitigación**: 512M es el mínimo que la propia documentación de Pi-hole declara suficiente, no un recorte arbitrario; si en la práctica no alcanza, es un valor a subir en un change posterior, informado por datos reales de uso.
- **[Riesgo]** `cpus` demasiado bajo estrangula el throughput DNS legítimo bajo carga alta de la LAN (muchos dispositivos, ráfagas de consultas) → **Mitigación**: los valores elegidos dejan margen (1.5-3 de los 4 núcleos típicos), y un throttling de CPU se nota rápido en latencia de resolución — es observable y ajustable sin urgencia.
- **[Trade-off]** Agregar un tier nuevo (ej. 4GB) en el futuro requiere un archivo overlay adicional, no solo un valor de configuración → aceptado explícitamente: es el costo directo de "menos piezas que ajustar" por instalación, decisión ya tomada por el usuario sobre la alternativa de variables `.env`.

## Migration Plan

1. Crear `docker-compose.pi-2gb.yml` y `docker-compose.pi-8gb.yml` en la raíz del repo, cada uno declarando solo `deploy.resources.limits` para `pihole` y `dnscrypt-proxy` (sin repetir el resto de la configuración de esos servicios).
2. Actualizar `README.md` ("Uso rápido" y "Estructura del repo") y `CONTRIBUTING.md` ("Convenciones") según lo descrito en `tasks.md`.
3. En un despliegue existente: `docker compose -f docker-compose.yml -f docker-compose.pi-<tier>gb.yml up -d` — recrea ambos contenedores con los límites aplicados. Mismo flujo ya conocido de otros changes de este repo.
4. Verificar con `docker stats` (o `docker compose -f ... -f ... top`) que los límites quedaron aplicados y que ambos contenedores arrancan y estabilizan su consumo por debajo del límite en operación normal.
5. Rollback: volver a `docker compose -f docker-compose.yml up -d` (sin el overlay de tier) — quita los límites, no requiere revertir nada más.

## Open Questions

- ¿Vale la pena, en un change futuro, agregar una verificación simple (ej. en `scripts/dev-test.sh` o un chequeo documentado) que compare la RAM real del host contra el tier elegido y avise si no coinciden? Fuera de alcance de este change — la mitigación actual es solo documentación.
- ¿Hace falta un tier intermedio (4GB, común en algunos Pi 4/400) más adelante? Se deja fuera de este change; el patrón de overlays lo admite como un archivo más sin romper nada de lo existente.
