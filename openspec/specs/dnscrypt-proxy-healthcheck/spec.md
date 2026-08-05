# dnscrypt-proxy-healthcheck Specification

## Purpose
Garantizar que la señal de salud de `dnscrypt-proxy` refleje si el servicio puede resolver consultas DNS reales — no solo si su puerto está escuchando — y que `pihole` no comience a aceptar tráfico DNS hasta que esa señal sea positiva, cerrando la ventana (~6 segundos medidos empíricamente en un arranque en frío) durante la cual `dnscrypt-proxy` todavía no tiene un servidor upstream vivo seleccionado y `pihole` podría devolver SERVFAIL sin que nada en el stack lo sepa o lo prevenga.

## Requirements

### Requirement: Healthcheck de resolución DNS real en dnscrypt-proxy
El servicio `dnscrypt-proxy` SHALL exponer un healthcheck que verifique resolución DNS real contra un dominio público estable, no solo que el puerto esté abierto.

#### Scenario: dnscrypt-proxy con upstream validado
- **WHEN** `dnscrypt-proxy` tiene un servidor upstream DNSCrypt vivo seleccionado y responde consultas en `127.0.0.1:5053`
- **THEN** el healthcheck SHALL reportar el contenedor como sano (`healthy`)

#### Scenario: dnscrypt-proxy sin upstream alcanzable
- **WHEN** `dnscrypt-proxy` no tiene conectividad hacia ningún servidor upstream configurado
- **THEN** el healthcheck SHALL reportar el contenedor como no sano, reflejando que no puede resolver consultas reales

### Requirement: pihole no arranca a servir tráfico antes de que dnscrypt-proxy esté sano
El servicio `pihole` SHALL declarar su dependencia de `dnscrypt-proxy` con `condition: service_healthy`, no con la condición por defecto de arranque de contenedor.

#### Scenario: Arranque en frío del stack
- **WHEN** se ejecuta `docker compose up` y `dnscrypt-proxy` todavía no reportó `healthy`
- **THEN** el contenedor `pihole` SHALL NOT iniciarse hasta que `dnscrypt-proxy` transicione a `healthy`

#### Scenario: dnscrypt-proxy healthy antes del start_period
- **WHEN** `dnscrypt-proxy` transiciona a `healthy` dentro de la ventana de gracia configurada
- **THEN** `pihole` SHALL iniciarse inmediatamente después, sin esperar tiempo adicional
