# container-resource-limits Specification

## Purpose
Evitar que los contenedores `pihole` y `dnscrypt-proxy` puedan agotar toda la memoria o CPU disponible del host — algo no solo teórico dado que Pi-hole FTL documenta memory leaks conocidos (`FTL_reload_all_domainlists`, `gravityDB_open`) — sin imponer un techo fijo que no tenga sentido a lo largo del rango de Raspberry Pi soportado (2GB a 8GB de RAM). Los límites viven exclusivamente en overlays de Docker Compose seleccionables explícitamente por el operador según el tier de RAM del host, dejando `docker-compose.yml` como base sin límites, de modo que un OOM-kill por exceso de memoria se resuelva con un reinicio aislado del contenedor afectado (vía `restart: unless-stopped`) en vez de degradar todo el host.

## Requirements

### Requirement: Compose base sin límites de recursos
`docker-compose.yml` SHALL NOT declarar límites de memoria ni de CPU para los servicios `pihole` ni `dnscrypt-proxy`. Los límites SHALL aplicarse exclusivamente vía un overlay seleccionado explícitamente por el operador al momento de levantar el stack.

#### Scenario: Levantar el stack sin overlay de recursos
- **WHEN** un operador ejecuta `docker compose up -d` usando solo `docker-compose.yml`
- **THEN** los contenedores `pihole` y `dnscrypt-proxy` SHALL arrancar sin ningún límite de memoria ni de CPU aplicado

### Requirement: Overlays de límites por tier de RAM de Raspberry Pi
El sistema SHALL proveer al menos dos overlays de Docker Compose, cada uno correspondiente a un tier de RAM de Raspberry Pi (2GB y 8GB), que declaren límites de memoria y CPU para los servicios `pihole` y `dnscrypt-proxy` mediante `deploy.resources.limits`. Cada overlay SHALL ser combinable con `docker-compose.yml` vía `-f` explícito, sin auto-mergearse (no SHALL llamarse `docker-compose.override.yml`).

#### Scenario: Desplegar en una Raspberry Pi de 2GB de RAM
- **WHEN** un operador ejecuta `docker compose -f docker-compose.yml -f docker-compose.pi-2gb.yml up -d`
- **THEN** los servicios `pihole` y `dnscrypt-proxy` SHALL arrancar con los límites de memoria y CPU definidos para el tier de 2GB

#### Scenario: Desplegar en una Raspberry Pi de 8GB de RAM
- **WHEN** un operador ejecuta `docker compose -f docker-compose.yml -f docker-compose.pi-8gb.yml up -d`
- **THEN** los servicios `pihole` y `dnscrypt-proxy` SHALL arrancar con los límites de memoria y CPU definidos para el tier de 8GB, distintos de los del tier de 2GB

#### Scenario: Un contenedor excede su límite de memoria
- **WHEN** el servicio `pihole` o `dnscrypt-proxy` corre con un overlay de tier aplicado y su consumo de memoria alcanza el límite declarado
- **THEN** el runtime de Docker SHALL terminar el contenedor por exceder el límite (OOM-kill)
- **AND** el contenedor SHALL reiniciarse automáticamente por la política `restart: unless-stopped` ya declarada en `docker-compose.yml`, sin intervención manual
