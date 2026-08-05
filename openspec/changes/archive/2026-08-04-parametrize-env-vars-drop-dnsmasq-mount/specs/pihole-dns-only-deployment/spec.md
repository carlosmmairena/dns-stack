## ADDED Requirements

### Requirement: Sin bind mounts sin uso
El servicio `pihole` SHALL NOT declarar bind mounts cuyo contenido no sea cargado por ninguna configuración activa. En particular, el mount de `/etc/dnsmasq.d` SHALL NOT declararse mientras `misc.etc_dnsmasq_d` permanezca en `false`.

#### Scenario: Carga de `/etc/dnsmasq.d` desactivada
- **WHEN** `misc.etc_dnsmasq_d` es `false` en la configuración de Pi-hole
- **THEN** `docker-compose.yml` SHALL NOT declarar un volumen que monte `/etc/dnsmasq.d` en el servicio `pihole`

#### Scenario: Se necesita una directiva dnsmasq custom en el futuro
- **WHEN** un mantenedor necesita inyectar una directiva dnsmasq que `pihole.toml`/`FTLCONF_*` no expone directamente
- **THEN** SHALL usar `FTLCONF_misc_dnsmasq_lines` (reproducible vía `docker-compose.yml`) antes de reintroducir el bind mount de `/etc/dnsmasq.d`
