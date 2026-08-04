## Context

Hoy `docker-compose.test.yml` existe pero solo se documenta a sí mismo, dentro de su propio comentario de cabecera. Nadie se entera de que existe salvo que abra el archivo, y usarlo implica escribir `docker compose -f docker-compose.yml -f docker-compose.test.yml <comando>` cada vez — se confirmó a mano durante `add-upstream-dns-redundancy` (levantar, dig A, dig AAAA, simular caída de un resolver, revertir, bajar), y repetir esa secuencia sin un script es tedioso y propenso a hacerse distinto cada vez.

## Goals / Non-Goals

**Goals:**
- Un solo comando memorable por operación común (`up`, `down`, `dig`, `logs`, `status`).
- Cero dependencias nuevas — solo `sh` y `docker compose`, ya requeridos.
- Una sola fuente de verdad para "cómo se usa esto", no documentación duplicada y potencialmente desincronizada entre el script y el `.yml`.

**Non-Goals:**
- No automatiza la simulación de caída de un resolver (editar `dnscrypt-proxy.toml`) — se guía como pasos manuales impresos por el script, no se ejecuta la mutación del archivo trackeado automáticamente.
- No es CI ni test runner con aserciones automáticas.
- No reemplaza `docker-compose.yml` de producción ni se usa en el despliegue real (Raspberry Pi).

## Decisions

**1. Script POSIX `sh`, no Makefile ni `justfile`.**
Ya evaluado en la exploración previa: `just` no está instalado en esta máquina (sería la primera dependencia externa del proyecto) y `make` no siempre viene en Raspberry Pi OS Lite. Un script en `sh` no depende de nada que el proyecto no requiera ya, y corre igual en la máquina de desarrollo que, si hiciera falta, en el propio Pi.

**2. La invocación `-f docker-compose.yml -f docker-compose.test.yml` vive codificada dentro del script, no en `COMPOSE_FILE`.**
Se descartó la variable de entorno `COMPOSE_FILE` (opción discutida en la exploración) porque si un dev la exporta en su shell y se olvida, cualquier `docker compose` suelto en esa terminal aplicaría el overlay de pruebas sin que lo note — incluyendo, en el peor caso, contra el compose de producción si algún día corre esto en el Pi. Encapsulando la invocación dentro del script, cada uso es explícito y aislado a esa sola llamada.

**3. `dig` como subcomando con tipo de registro opcional (default `A`).**
Reutiliza el servicio `dns-test` ya declarado en `docker-compose.test.yml` — no se agrega ningún servicio nuevo. `dev-test.sh dig example.com AAAA` cubre el caso dual-stack sin duplicar lógica.

**4. Documentación: `CONTRIBUTING.md` nuevo + una línea en la "Estructura del repo" del README.**
El README ya se mantiene deliberadamente mínimo y enfocado en quien despliega el stack, no en quien lo desarrolla (decisión tomada en un change anterior). Crear un `CONTRIBUTING.md` separado mantiene esa separación de audiencias. Se agrega solo una línea en el árbol de archivos del README (`scripts/`, `docker-compose.test.yml`) para que quien lea el README sepa que existen, sin explicarlos ahí — la explicación completa vive en `CONTRIBUTING.md` y en `scripts/dev-test.sh help`.

**5. No se automatiza la simulación de failover.**
La alternativa era que `dev-test.sh failover <server_name>` edite `dnscrypt-proxy.toml` automáticamente. Se descarta: un script de pruebas que muta un archivo trackeado por git sin que el dev lo vea es sorpresivo y arriesgado (¿qué pasa si falla a la mitad?). En su lugar, `dev-test.sh help` imprime la secuencia manual exacta ya validada (agregar `disabled_server_names`, reiniciar, probar, revertir, reiniciar) para que el dev la ejecute con control total en cada paso.

## Flujo del script

```
dev@laptop$ scripts/dev-test.sh up
            │
            └─▶ docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --build
                (pihole sin puertos publicados, dnscrypt-proxy con los 2 upstreams)

dev@laptop$ scripts/dev-test.sh dig example.com AAAA
            │
            └─▶ docker compose ... run --rm dns-test dig @pihole example.com AAAA +dnssec
                (contenedor efímero, mismo pihole_net, sin tocar el host)

dev@laptop$ scripts/dev-test.sh logs dnscrypt-proxy
            │
            └─▶ docker compose ... logs dnscrypt-proxy

dev@laptop$ scripts/dev-test.sh down
            │
            └─▶ docker compose ... down
                (contenedores y red del overlay eliminados, nada persiste)
```

## Risks / Trade-offs

- **[Riesgo]** Documentación duplicada entre el comentario de `docker-compose.test.yml` y el `help` del script → **Mitigación**: recortar el comentario del `.yml` a una línea que apunte a `scripts/dev-test.sh help` como fuente única de verdad.
- **[Riesgo]** El script falla de forma confusa si Docker no está corriendo → **Mitigación**: chequeo explícito de `docker info` al inicio de cada subcomando, con mensaje guiado (no un stack trace crudo de Docker).
- **[Riesgo]** Alguien corre el script pensando que es el método de despliegue real → **Mitigación**: el banner de `help` aclara explícitamente que es solo para pruebas locales, y que producción usa `docker-compose.yml` solo, sin overlay.

## Migration Plan

1. Crear `scripts/dev-test.sh`, marcarlo ejecutable (`chmod +x`).
2. Recortar el comentario de cabecera de `docker-compose.test.yml` para apuntar a `scripts/dev-test.sh help`.
3. Crear `CONTRIBUTING.md` documentando el flujo de desarrollo/pruebas.
4. Agregar `scripts/` y `docker-compose.test.yml` a la "Estructura del repo" en `README.md`.
5. Probar cada subcomando de punta a punta (up, dig A, dig AAAA, logs, status, down).
6. **Rollback**: eliminar el script y revertir los tres archivos de documentación — no hay estado ni datos involucrados.

## Open Questions

- ¿`up` siempre debe reconstruir la imagen (`--build`), o conviene un modo rápido sin rebuild para iteraciones donde solo cambió el `.toml`? Se deja para decidir durante la implementación de tareas.
