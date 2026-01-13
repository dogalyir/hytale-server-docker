# Hytale Docker Server

Servidor de Hytale en contenedor Docker con descarga automática de assets y soporte para autenticación OAuth2.

## Estado

🚧 **En desarrollo**

Este proyecto está actualmente en fase de desarrollo. Puede haber cambios importantes en la configuración y funcionalidades.

## Requisitos

- Docker
- Docker Compose
- Para Mac Apple Silicon: Docker Desktop con emulación x86_64

## Modos de ejecución

### Modo Offline (sin autenticación)

```bash
# Iniciar el servidor sin autenticación
docker-compose up -d
```

### Modo Autenticado (OAuth2 Device Code Flow)

El servidor requiere autenticación para aceptar conexiones de jugadores y acceder a las APIs de servicio.

#### Paso 1: Obtener tokens de autenticación

```bash
# Ejecutar el script de autenticación
./auth.sh
```

El script te guiará por el proceso:
1. Solicita un device code a Hytale OAuth
2. Muestra una URL y código para autorizar
3. Espera a que completes la autorización en tu navegador
4. Obtiene el access token y refresh token
5. Crea una sesión de juego
6. Guarda los tokens en `hytale_tokens.env`

#### Paso 2: Iniciar el servidor con autenticación

```bash
# Cargar los tokens e iniciar el servidor
docker-compose --env-file hytale_tokens.env up -d
```

#### Refrescar tokens

Los tokens de sesión expiran en 1 hora. Para refrescarlos:

```bash
# Volver a ejecutar el script (usará el refresh_token guardado)
./auth.sh
```

## Características

- Descarga automática de assets de Hytale
- Autenticación OAuth2 mediante Device Code Flow
- Persistencia de datos en volumen
- Verificación de existencia de assets antes de descargar
- Limpieza automática de archivos temporales
- Soporte para modo offline y autenticado

## Configuración

Los archivos del servidor se guardan en `./hytale_data/`. Si deseas conservar los assets entre reinicios, asegúrate de no eliminar esta carpeta.

### Variables de entorno

| Variable | Descripción |
|----------|-------------|
| `HYTALE_SERVER_SESSION_TOKEN` | Token de sesión del servidor (JWT) |
| `HYTALE_SERVER_IDENTITY_TOKEN` | Token de identidad del servidor (JWT) |
| `WORKDIR` | Directorio de trabajo del servidor (default: `/app`) |

## Estructura

```
.
├── Dockerfile                  # Imagen del contenedor
├── docker-compose.yml           # Orquestación del servicio
├── entrypoint.sh                # Script de inicialización
├── auth.sh                      # Script de autenticación OAuth2
├── hytale_tokens.env            # Tokens generados (creado automáticamente)
├── hytale_tokens.env.example    # Ejemplo de archivo de tokens
└── hytale_data/                 # Datos del servidor (creado automáticamente)
```

## Comandos útiles

```bash
# Ver logs del servidor
docker-compose logs -f

# Detener el servidor
docker-compose down

# Reconstruir la imagen
docker-compose build --no-cache

# Limpiar datos del servidor (¡cuidado!)
rm -rf hytale_data/
```

## Licencia

MIT
