#!/bin/sh
# Pruebas locales del stack DNS, sin exponer puertos al host.
# Ver `scripts/dev-test.sh help` para uso completo.
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

dc() {
  docker compose -f docker-compose.yml -f docker-compose.test.yml "$@"
}

check_docker() {
  if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker no está corriendo o no es accesible." >&2
    echo "Inicia Docker (Docker Desktop o el daemon) y volvé a intentar." >&2
    exit 1
  fi
}

cmd_up() {
  check_docker
  dc up -d --build
}

cmd_down() {
  check_docker
  dc down
}

cmd_dig() {
  check_docker
  domain="${1:-}"
  rtype="${2:-A}"
  if [ -z "$domain" ]; then
    echo "Uso: scripts/dev-test.sh dig <dominio> [A|AAAA]" >&2
    exit 1
  fi
  dc run --rm dns-test dig @pihole "$domain" "$rtype" +dnssec
}

cmd_logs() {
  check_docker
  dc logs --tail=200 "${1:-dnscrypt-proxy}"
}

cmd_status() {
  check_docker
  dc ps
}

cmd_help() {
  cat <<'EOF'
scripts/dev-test.sh — pruebas locales del stack DNS, sin exponer puertos al host.

Uso: scripts/dev-test.sh <subcomando> [args]

Subcomandos:
  up                       Levanta pihole + dnscrypt-proxy con el overlay de pruebas
                            (docker-compose.test.yml). No publica ningún puerto al host.
  down                      Baja y limpia el overlay de pruebas.
  dig <dominio> [A|AAAA]    Consulta DNS contra Pi-hole vía un contenedor efímero en la
                            misma red interna. Tipo de registro opcional, default A.
  logs [servicio]           Logs del servicio (default: dnscrypt-proxy).
  status                    Estado de los contenedores del overlay.
  help                      Esta ayuda.

¿Por qué docker-compose.test.yml y no docker-compose.override.yml?
  docker-compose.override.yml se mergea automáticamente con CUALQUIER `docker compose`
  suelto en este directorio. Si este repo se despliega tal cual en la Raspberry Pi real,
  ese automerge quitaría los puertos publicados en producción sin que nadie lo pida.
  docker-compose.test.yml requiere pasarlo explícito con -f, así que nunca se cuela por
  accidente fuera de este script.

Simular la caída de un resolver upstream (guiado, manual — este script NO edita
dnscrypt-proxy.toml por vos):
  1. Editar dnscrypt-proxy/dnscrypt-proxy.toml y agregar, junto a server_names:
       disabled_server_names = ['quad9-dnscrypt-ip4-filter-pri']
  2. docker compose -f docker-compose.yml -f docker-compose.test.yml restart dnscrypt-proxy
  3. scripts/dev-test.sh dig example.com   # confirmar que sigue resolviendo (vía el otro resolver)
  4. Revertir el paso 1 (quitar la línea disabled_server_names)
  5. Repetir el paso 2 para restaurar ambos resolvers
EOF
}

case "${1:-help}" in
  up) shift; cmd_up "$@" ;;
  down) shift; cmd_down "$@" ;;
  dig) shift; cmd_dig "$@" ;;
  logs) shift; cmd_logs "$@" ;;
  status) shift; cmd_status "$@" ;;
  help|-h|--help) cmd_help ;;
  *)
    echo "Subcomando desconocido: $1" >&2
    echo >&2
    cmd_help >&2
    exit 1
    ;;
esac
