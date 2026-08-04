## ADDED Requirements

### Requirement: Multiple independent DNSCrypt upstream resolvers
El sistema SHALL resolver consultas DNS a través de al menos dos resolvers upstream DNSCrypt operados independientemente, configurados en `server_names` de dnscrypt-proxy.

#### Scenario: Resolver primario disponible
- **WHEN** dnscrypt-proxy consulta un resolver upstream y el primario (Quad9) responde correctamente
- **THEN** la respuesta se retorna a Pi-hole sin recurrir al resolver secundario

#### Scenario: Resolver primario no disponible
- **WHEN** el resolver upstream primario (Quad9) no responde o excede el timeout
- **THEN** dnscrypt-proxy SHALL enrutar las consultas subsiguientes hacia el resolver secundario (CleanBrowsing Security) sin intervención manual

### Requirement: Criterios de vetting para resolvers upstream
Cada resolver upstream configurado SHALL usar el protocolo DNSCrypt, SHALL validar DNSSEC, SHALL NOT registrar información de cliente personalmente identificable en su capa pública/gratuita, y SHALL bloquear dominios maliciosos/malware.

#### Scenario: Evaluación de un nuevo candidato a resolver
- **WHEN** se propone un nuevo resolver como adición a `server_names`
- **THEN** su validación DNSSEC y su política de no-log MUST confirmarse contra la documentación técnica o política de privacidad propia del proveedor, no solo su página de producto/marketing, antes de agregarlo

### Requirement: Documentar la limitación de los filtros require_*
La configuración SHALL documentar que `require_dnssec`, `require_nolog` y `require_nofilter` no filtran resolvers cuando `server_names` está fijado explícitamente, para que futuros mantenedores no asuman una validación automática que no ocurre.

#### Scenario: Un mantenedor edita server_names
- **WHEN** un mantenedor agrega o quita una entrada de `server_names`
- **THEN** el comentario en el `.toml` SHALL recordarle que el resolver debe ser vetted manualmente, ya que los flags `require_*` no validan entradas explícitas
