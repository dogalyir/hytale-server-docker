# Hytale Docker Server

Servidor de Hytale en contenedor Docker con descarga automática de assets.

## Estado

🚧 **En desarrollo**

Este proyecto está actualmente en fase de desarrollo. Puede haber cambios importantes en la configuración y funcionalidades.

## Requisitos

- Docker
- Docker Compose
- Para Mac Apple Silicon: Docker Desktop con emulación x86_64

## Uso

```bash
# Clonar el repositorio
git clone <repo-url>
cd HytaleDocker

# Iniciar el servidor
docker-compose up -d

# Ver logs
docker-compose logs -f

# Detener el servidor
docker-compose down
```

## Características

- Descarga automática de assets de Hytale
- Persistencia de datos en volumen
- Verificación de existencia de assets antes de descargar
- Limpieza automática de archivos temporales

## Configuración

Los archivos del servidor se guardan en `./hytale_data/`. Si deseas conservar los assets entre reinicios, asegúrate de no eliminar esta carpeta.

## Estructura

```
.
├── Dockerfile          # Imagen del contenedor
├── docker-compose.yml   # Orquestación del servicio
├── entrypoint.sh        # Script de inicialización
└── hytale_data/         # Datos del servidor (creado automáticamente)
```

## Licencia

MIT
