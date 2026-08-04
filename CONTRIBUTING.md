# Desarrollo y pruebas locales

Esta guía es para quien va a modificar el stack (`dnscrypt-proxy.toml`, `docker-compose.yml`, etc.), no para quien solo quiere desplegarlo — para eso ver el [README](README.md).

## Probar un cambio sin exponer puertos

`docker-compose.test.yml` es un overlay que se combina con `docker-compose.yml` para levantar el stack localmente sin publicar ningún puerto al host (nada de puerto 53 real ocupado en tu máquina) y agrega un contenedor efímero (`dns-test`) para consultar directo contra Pi-hole por la red interna de Docker.

No se llama `docker-compose.override.yml` a propósito: ese nombre se combina automáticamente con cualquier `docker compose` suelto que corras en el directorio. Si este mismo repo se despliega en la Raspberry Pi real, ese automerge te quitaría los puertos publicados en producción sin que lo pidas. `docker-compose.test.yml` requiere pasarse explícito con `-f`, así que nunca se cuela por accidente fuera del flujo de pruebas.

### Uso

```bash
scripts/dev-test.sh up                       # levanta el stack de pruebas
scripts/dev-test.sh dig example.com          # dig A contra Pi-hole
scripts/dev-test.sh dig example.com AAAA     # dig AAAA (dual-stack)
scripts/dev-test.sh logs                     # logs de dnscrypt-proxy
scripts/dev-test.sh status                   # estado de los contenedores
scripts/dev-test.sh down                     # baja y limpia todo
```

Corré `scripts/dev-test.sh help` para el detalle completo, incluyendo los pasos guiados para simular la caída de un resolver upstream (el script no edita `dnscrypt-proxy.toml` por vos — esa parte es manual y a propósito).

## Convenciones

- Artefactos de OpenSpec y mensajes de commit (conventional commits) en español; código en inglés.
- Cualquier cambio que agregue una imagen o dependencia nueva debe fijar versión explícita y su mecanismo de verificación (firma/checksum) — ver `dnscrypt-proxy/Dockerfile` como referencia.
- Los cambios de infraestructura de este repo se documentan con [OpenSpec](openspec/) antes de implementarse (`openspec/changes/`).
