## Context

`dnscrypt-proxy/Dockerfile` construye una imagen mínima de dos etapas: la primera descarga y verifica (minisign) el binario oficial de `dnscrypt-proxy`; la segunda es `alpine:3.20` + `ca-certificates` + el binario, corriendo como usuario no-root `dnscrypt`. No tiene ningún `HEALTHCHECK`. `docker-compose.yml` tampoco define uno para este servicio, y `pihole` depende de él con `depends_on: - dnscrypt-proxy` (forma corta), que en Docker Compose es el default `condition: service_started` — confirmado contra el código fuente de `compose-go`: esa condición no espera nada más allá de que el contenedor haya arrancado.

Se midió empíricamente un arranque en frío: `dnscrypt-proxy` abre el puerto 5053 casi al instante, pero tarda hasta ~6 segundos adicionales en tener un servidor upstream validado (fetch del listado de resolvers + prueba de certificados DNSCrypt contra Quad9/CleanBrowsing). En esa ventana, consultas que le lleguen a `pihole` pueden fallar (SERVFAIL) sin que nada en el stack lo prevenga ni lo reporte.

Se comparó `bind-tools` (`dig`) contra `ldns`/`drill` para implementar el healthcheck — `drill` fue la decisión (+9.3 MB de imagen para `bind-tools` vs. una medición inicial de +2.4 MB para `drill`, 6 CVEs históricos en el tracker de Alpine para `ldns` vs. ~81 para `bind`). Esa medición inicial resultó estar hecha contra el paquete equivocado (`ldns-tools`, que no incluye el binario `drill`) — corregida durante la implementación a `drill=1.8.3-r2`, el paquete Alpine correcto, con un delta real de solo +0.5 MB (ver Decisión 1 y Riesgos).

## Goals / Non-Goals

**Goals:**
- Que `dnscrypt-proxy` exponga una señal de salud basada en resolución DNS real (no solo puerto abierto).
- Que `pihole` no arranque a servir tráfico hasta que esa señal sea positiva, cerrando la ventana de carrera medida.
- Mantener la disciplina de este repo sobre dependencias nuevas: versión de paquete fijada explícitamente, mecanismo de verificación documentado.

**Non-Goals:**
- No se resuelve la causa raíz de por qué el arranque en frío tarda ~6 segundos (el cache de resolvers de `dnscrypt-proxy` no persiste entre recreaciones — hallazgo de una exploración anterior). Este change hace que la carrera sea segura, no que el arranque sea más rápido.
- No se cambia a `bind-tools`/`dig` — ya evaluado y descartado.
- No se toca la resolución ni el cifrado DNS en sí (Quad9/CleanBrowsing, DNSSEC, filtrado) — es un change de orquestación de arranque únicamente.
- No se agrega ningún healthcheck nuevo a `pihole` — la imagen oficial ya trae uno (`dig ... @127.0.0.1 pi.hole`), y hoy no hay ningún servicio que dependa de `pihole`, así que no hace falta gatillarlo.

## Decisions

### 1. `drill` (paquete Alpine `drill`, no `ldns-tools`) en vez de `dig` (`bind-tools`)
Ya evaluado en la exploración previa a nivel de familia (`ldns` vs. `bind`): la dependencia `ldns` tiene 6 CVEs históricos en el tracker de seguridad de Alpine (3 sin resolver) contra ~81 de `bind` (12 sin resolver). `bind-tools` además arrastra librerías sin relación con el caso de uso (Kerberos, XML) porque `dig` comparte código con el servidor DNS completo de BIND9, no solo el cliente.

Corrección hecha durante la implementación: el paquete Alpine correcto para obtener el binario `drill` es **`drill`**, no `ldns-tools` (ese último trae utilidades de ejemplo de ldns — `ldns-chaos`, `ldns-zcat`, etc. — pero no incluye `drill`; confirmado con `apk info -L ldns-tools` vs. `apk info -L drill`). Con el paquete correcto, el delta real de imagen es **+0.5 MB** (32 MB → 32.5 MB), más liviano que la medición inicial de +2.4 MB hecha con el paquete equivocado — `drill` no arrastra las utilidades de ejemplo ni `libpcap` que sí trae `ldns-tools`.

### 2. Dominio de prueba: `example.com`
Decisión explícita del usuario. Dominio público, estable, reservado por IANA — no depende de la disponibilidad de un proveedor específico (a diferencia de un dominio propio de Quad9/CleanBrowsing) y no es candidato a bloqueo por listas de publicidad/malware. Ejecutar `drill -p 5053 example.com @127.0.0.1` ejercita el camino completo: puerto abierto → selección de upstream → resolución vía DNSCrypt → respuesta — no solo si el puerto acepta conexiones.

Corrección hecha durante la implementación: el orden de argumentos de `drill` importa — `@servidor` tiene que ir al final (`drill [opciones] nombre [tipo] @servidor`), no al principio como en `dig`. `drill @127.0.0.1 -p 5053 example.com` (el orden "estilo dig" que se había escrito inicialmente) falla con `Error: could not send or receive, because of network error`, aunque el puerto esté efectivamente abierto (confirmado con `nc`) — el parser de argumentos de `drill` no lo interpreta como se espera. Verificado empíricamente probando varios órdenes hasta confirmar el que funciona.

Trade-off aceptado explícitamente: el healthcheck depende de que haya conectividad real a internet. Si no la hay, `dnscrypt-proxy` se reporta "unhealthy" — comportamiento correcto (no hay upstream, no puede resolver), pero implica que `pihole` no arranca a servir tráfico si el host no tiene salida a internet en ese momento, incluso si el problema no es de `dnscrypt-proxy` en sí.

### 3. `depends_on` de `pihole`: forma larga con `condition: service_healthy`
Es el cambio que efectivamente cierra la ventana de carrera — sin esto, el healthcheck solo sería informativo (visible en `docker compose ps`) pero no cambiaría el comportamiento de arranque actual. Alternativa considerada — agregar el healthcheck sin tocar `depends_on`: descartada, no resuelve el problema que motivó el change, solo lo hace visible.

### 4. Parámetros de tiempo del healthcheck
Dado que el arranque en frío normal mide hasta ~6 segundos hasta tener upstream validado, `start_period` (ventana de gracia durante la cual fallos no cuentan para marcar "unhealthy") se fija en un valor que cubre ese caso con margen, para no generar falsos negativos en cada arranque normal. Valores propuestos:
- `interval: 10s`
- `timeout: 5s`
- `retries: 3`
- `start_period: 15s`

Esto es un punto de partida razonable, no una cifra rígida — documentado explícitamente el motivo (~6s medido + margen) para que un futuro mantenedor no lo reduzca sin saber por qué está en ese valor.

### 5. Instalación de `drill` con versión fijada, antes del `USER dnscrypt`
`apk add drill=1.8.3-r2` (versión confirmada disponible en el repositorio de `alpine:3.20`) se agrega en la etapa final del Dockerfile, como root, antes del `USER dnscrypt` — igual que `ca-certificates` ya se instala hoy. La verificación viene del propio `apk`: Alpine firma su índice de repositorio y sus paquetes, y `apk` valida esa firma automáticamente contra las claves ya embebidas en la imagen base `alpine:3.20`. Es un mecanismo distinto al `minisign` manual que usa este mismo Dockerfile para el binario de `dnscrypt-proxy` (que se descarga crudo desde GitHub Releases, fuera de cualquier gestor de paquetes con verificación propia) — pero es el mecanismo apropiado dado cómo se obtiene esta dependencia, y es consistente con la convención del repo de fijar versión explícita para cualquier dependencia nueva.

El proceso del `HEALTHCHECK` (invocado por el daemon de Docker) corre en el contexto de usuario configurado del contenedor — `dnscrypt` (no-root), igual que el proceso principal. `drill` no gana ningún privilegio adicional.

## Risks / Trade-offs

- **[Riesgo]** `start_period` insuficiente → falsos "unhealthy" en cada arranque normal, retrasando a `pihole` más de lo necesario → **Mitigación**: fijado con margen sobre el ~6s medido empíricamente; documentado el porqué del valor.
- **[Riesgo]** El healthcheck depende de conectividad real a internet — si el host no tiene salida en el momento del arranque, `pihole` queda bloqueado esperando aunque `dnscrypt-proxy` esté sano en sí mismo → **Mitigación**: comportamiento intencional y correcto (sin upstream, no hay DNS que servir de todas formas); documentado explícitamente en el README.
- **[Riesgo]** Se agrega una dependencia nueva (`drill`) a la imagen de producción, aunque ya se compare favorablemente contra la alternativa descartada → **Mitigación**: versión fijada, verificación vía firma de `apk`, tamaño y superficie CVE medidos y documentados antes de decidir.
- **[Trade-off]** No se resuelve la causa raíz del arranque lento (cache de resolvers no persistido) — un `docker compose up -d` en un host con conectividad lenta puede tardar más de los 15s de `start_period` propuestos en volverse sano, lo cual es correcto (espera más) pero no es instantáneo.

## Migration Plan

1. Editar `dnscrypt-proxy/Dockerfile`: agregar `RUN apk add --no-cache drill=1.8.3-r2` en la etapa final, antes de `USER dnscrypt`.
2. Reconstruir la imagen y verificar manualmente que `drill` funciona dentro del contenedor contra `127.0.0.1:5053`.
3. Agregar el bloque `healthcheck:` al servicio `dnscrypt-proxy` en `docker-compose.yml` con el comando `drill` y los parámetros de tiempo de la Decisión 4.
4. Cambiar `depends_on` de `pihole` a la forma larga con `condition: service_healthy` para `dnscrypt-proxy`.
5. Verificación local: `docker compose up`, observar la transición `starting` → `healthy` con `docker inspect dnscrypt-proxy --format '{{json .State.Health}}'`, confirmar que `pihole` no arranca hasta que eso ocurra.
6. Desplegar en el host de producción con la misma verificación, más el chequeo dual-stack (`dig` A/AAAA con `+dnssec`) ya establecido en changes anteriores como regresión — nada de la resolución DNS en sí debería cambiar.
7. Rollback: revertir `Dockerfile`/`docker-compose.yml`, reconstruir, redesplegar. Sin impacto en datos/estado — cambio puramente de orquestación.

## Open Questions

- Los valores de `interval`/`timeout`/`retries`/`start_period` de la Decisión 4 son un punto de partida razonable basado en una sola medición de arranque en frío — vale la pena confirmarlos con un par de arranques más en el host de producción real antes de darlos por definitivos.
