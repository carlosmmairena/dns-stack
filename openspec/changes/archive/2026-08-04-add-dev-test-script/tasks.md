## 1. Script

- [x] 1.1 Crear `scripts/dev-test.sh` (POSIX sh) con subcomandos `up`, `down`, `dig <dominio> [A|AAAA]`, `logs [servicio]`, `status`, `help`
- [x] 1.2 Implementar chequeo de `docker info` al inicio de cada subcomando, con mensaje guiado si Docker no está corriendo (en vez de un error crudo)
- [x] 1.3 Marcar el script como ejecutable (`chmod +x scripts/dev-test.sh`)

## 2. Documentación

- [x] 2.1 Recortar el comentario de cabecera de `docker-compose.test.yml` para apuntar a `scripts/dev-test.sh help` como fuente única de verdad (evitar duplicar instrucciones en dos archivos)
- [x] 2.2 Crear `CONTRIBUTING.md` documentando el flujo de desarrollo/pruebas local (por qué existe `docker-compose.test.yml` separado de `.override.yml`, cómo usar el script)
- [x] 2.3 Agregar `scripts/` y `docker-compose.test.yml` a la "Estructura del repo" en `README.md`

## 3. Verificación

- [x] 3.1 Ejecutar `scripts/dev-test.sh up` y confirmar que no se publica ningún puerto al host (`docker port pihole` vacío)
- [x] 3.2 Ejecutar `scripts/dev-test.sh dig example.com` y confirmar resolución A con flag `ad`
- [x] 3.3 Ejecutar `scripts/dev-test.sh dig example.com AAAA` y confirmar resolución AAAA con flag `ad` (verificación dual-stack)
- [x] 3.4 Ejecutar `scripts/dev-test.sh logs` y `scripts/dev-test.sh status` y confirmar salida legible
- [x] 3.5 Ejecutar `scripts/dev-test.sh` sin argumentos y con un subcomando inválido, confirmar que ambos casos muestran la ayuda en vez de fallar en silencio
- [x] 3.6 Ejecutar `scripts/dev-test.sh down` y confirmar que no queda ningún contenedor ni red del overlay corriendo
