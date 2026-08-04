# dev-test-workflow Specification

## Purpose
Dar a cualquier dev un único script memorable y guiado (`scripts/dev-test.sh`) para levantar, verificar y bajar el stack de pruebas local (`docker-compose.yml` + `docker-compose.test.yml`), sin publicar puertos al host, sin agregar dependencias nuevas al proyecto, y sin mutar automáticamente configuración trackeada por git.

## Requirements

### Requirement: Script único con subcomandos guiados
El proyecto SHALL exponer un único script (`scripts/dev-test.sh`) con subcomandos para levantar, verificar y bajar el stack de pruebas local usando `docker-compose.test.yml`, sin requerir que el dev memorice o escriba la invocación completa de `docker compose -f`.

#### Scenario: Dev levanta el stack de pruebas
- **WHEN** un dev ejecuta `scripts/dev-test.sh up`
- **THEN** el script SHALL levantar `docker-compose.yml` + `docker-compose.test.yml` sin publicar ningún puerto al host

#### Scenario: Dev sin subcomando o con uno inválido
- **WHEN** un dev ejecuta `scripts/dev-test.sh` sin argumentos o con un subcomando no reconocido
- **THEN** el script SHALL imprimir la ayuda de uso (`help`) en vez de fallar en silencio

### Requirement: Verificación dual-stack vía subcomando dig
El subcomando `dig` SHALL aceptar un dominio y un tipo de registro opcional (`A` o `AAAA`, default `A`), y SHALL ejecutar la consulta contra Pi-hole a través del contenedor efímero `dns-test` de la red interna, sin exponer puertos al host.

#### Scenario: Verificación IPv4 por defecto
- **WHEN** un dev ejecuta `scripts/dev-test.sh dig example.com`
- **THEN** el script SHALL consultar un registro `A` contra Pi-hole con `+dnssec` y mostrar la respuesta completa

#### Scenario: Verificación IPv6 explícita
- **WHEN** un dev ejecuta `scripts/dev-test.sh dig example.com AAAA`
- **THEN** el script SHALL consultar un registro `AAAA` contra Pi-hole con `+dnssec` y mostrar la respuesta completa

### Requirement: Sin dependencias nuevas ni mutación de config trackeada
El script SHALL ejecutarse únicamente con `sh` y `docker compose` ya requeridos por el proyecto, y SHALL NOT modificar automáticamente ningún archivo de configuración trackeado por git (ej. `dnscrypt-proxy.toml`) como efecto de alguno de sus subcomandos.

#### Scenario: Guía para simular caída de un resolver
- **WHEN** un dev ejecuta `scripts/dev-test.sh help`
- **THEN** el script SHALL imprimir los pasos manuales guiados para simular la caída de un resolver upstream, sin ejecutar ninguna edición de archivo por sí mismo
