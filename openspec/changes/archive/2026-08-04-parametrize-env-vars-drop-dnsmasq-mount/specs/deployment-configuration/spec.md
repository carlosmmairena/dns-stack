## ADDED Requirements

### Requirement: Valores específicos de la instalación viven en `.env`
El sistema SHALL externalizar a `.env` los valores que son hechos de cada instalación (huso horario, subnet LAN usada en la ACL del webserver), en vez de hardcodearlos en `docker-compose.yml`. `docker-compose.yml` SHALL conservar la forma revisable de las decisiones de política (qué orígenes puede acceder al webserver) mediante interpolación de esas variables, no reemplazándolas por un único valor opaco.

#### Scenario: Desplegar en una LAN con subnet distinta a la de ejemplo
- **WHEN** un usuario despliega este stack en una LAN cuya subnet no es `192.168.90.0/24`
- **THEN** SHALL poder ajustar `LAN_SUBNET` en su `.env` local sin modificar `docker-compose.yml`

#### Scenario: Desplegar en un huso horario distinto
- **WHEN** un usuario despliega este stack fuera de `America/Costa_Rica`
- **THEN** SHALL poder ajustar `TZ` en su `.env` local sin modificar `docker-compose.yml`

### Requirement: Variable de subnet LAN requerida explícitamente
El sistema SHALL fallar el arranque de forma explícita si `LAN_SUBNET` no está definida en `.env`, en vez de continuar con un valor vacío que produzca una ACL de webserver malformada.

#### Scenario: `.env` sin `LAN_SUBNET` definida
- **WHEN** se ejecuta `docker compose up` sin que `.env` defina `LAN_SUBNET`
- **THEN** Docker Compose SHALL rechazar el arranque con un mensaje de error explícito, sin llegar a iniciar el contenedor `pihole` con una ACL malformada
