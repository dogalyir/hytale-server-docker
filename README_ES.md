# 🎮 Servidor Hytale Docker

<div align="center">

![Status](https://img.shields.io/badge/status-dev-yellow)
![License](https://img.shields.io/badge/license-MIT-blue)
![Docker](https://img.shields.io/badge/docker-supported-blue)
![Platform](https://img.shields.io/badge/platform-linux%2Famd64-orange)

**Servidor de Hytale en contenedor Docker con descarga automática de assets y soporte para autenticación OAuth2**

[Características](#-características) • [Instalación](#-instalación) • [Uso](#-uso) • [Configuración](#-configuración)

[🇺🇸 Read in English](README.md)

</div>

---

## 📋 Estado

> 🚧 **En desarrollo**

Este proyecto está actualmente en fase de desarrollo. Puede haber cambios importantes en la configuración y funcionalidades.

## ✨ Características

- 🚀 **Descarga automática** de assets de Hytale mediante CLI oficial
- 🔐 **Autenticación OAuth2** mediante Device Code Flow
- 🔄 **Refresco automático de tokens** - Tokens de sesión se refrescan en cada inicio
- 💾 **Persistencia de datos** en volúmenes Docker
- ⚡ **Smart caching** - Solo descarga cuando es necesario
- 🧹 **Limpieza automática** de archivos temporales
- 🔄 **Modos flexibles** - Offline o Autenticado
- 🏗️ **Multi-arquitectura** - Soporte para x86_64 y ARM64

---

## 📦 Requisitos

| Requisito | Versión mínima | Notas |
|-----------|----------------|-------|
| Docker | 20.10+ | [Instalar](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.0+ | [Instalar](https://docs.docker.com/compose/install/) |
| macOS | Apple Silicon | Requiere emulación x86_64 |

---

## 🚀 Instalación

### Opción A: Usar imagen publicada (recomendado)

```bash
# Clonar el repositorio
git clone <repo-url>
cd HytaleDocker

# Importante: Modificar docker-compose.yml para usar tu imagen
# ghcr.io/dogalyir/hytale-server-docker:main
# Esta imagen se construye automáticamente en GitHub Container Registry cuando haces push a main

# Iniciar el servidor
docker-compose up -d
```

> 💡 **Tip**: La imagen se construye automáticamente en GitHub Container Registry cada vez que haces push a la rama `main`.

### Opción B: Construir localmente

```bash
# Clonar el repositorio
git clone <repo-url>
cd HytaleDocker

# Descomentar la línea 'build: .' en docker-compose.yml
# Comentar la línea 'image: ...'

# Construir e iniciar
docker-compose up -d --build
```

## 🎯 Uso

### 1️⃣ Modo Offline (sin autenticación)

Para pruebas locales sin conexión a servicios de Hytale:

```bash
docker-compose up -d
```

### 2️⃣ Modo Autenticado (OAuth2 Device Code Flow)

Para producción y conexión con jugadores:

#### 📝 Paso 1: Obtener tokens de autenticación

```bash
# Ejecutar el script interactivo de autenticación
./auth.sh
```

<details>
<summary>📖 ¿Qué hace el script?</summary>

El `auth.sh` automatiza todo el proceso OAuth2 Device Code Flow:

1. 🔄 Solicita un `device_code` a los servidores de Hytale OAuth
2. 🌐 Muestra URL y código para autorización en navegador
3. ⏳ Espera que completes la autorización (hasta 15 min)
4. 🎉 Obtiene `access_token` y `refresh_token`
5. 🎮 Crea sesión de juego mediante API
6. 💾 Guarda tokens en `hytale_tokens.env`

</details>

#### 🚀 Paso 2: Iniciar el servidor autenticado

```bash
# Cargar tokens e iniciar el servidor
docker-compose --env-file hytale_tokens.env up -d
```

#### 🔄 Refresco automático de tokens

> ⚡ **Nueva característica**: Los tokens de sesión se refrescan automáticamente en cada inicio del servidor!

**Cómo funciona:**

1. El servidor verifica si hay tokens OAuth disponibles (`HYTALE_ACCESS_TOKEN`, `HYTALE_REFRESH_TOKEN`, `HYTALE_PROFILE_UUID`)
2. Si están disponibles, automáticamente:
   - Refresca el access token de OAuth usando el refresh_token
   - Crea una nueva sesión de juego con el access_token refrescado
   - Guarda los nuevos tokens para la próxima vez
3. El servidor inicia con tokens de sesión frescos cada vez

**Expiración de tokens:**

| Tipo de Token | Expiración |
|--------------|------------|
| OAuth Access Token | 1 hora (refrescado automáticamente) |
| OAuth Refresh Token | 30 días |
| Game Session | 1 hora (recreado en cada inicio) |

**Refresco manual (si es necesario):**

```bash
# Volver a ejecutar el script de autenticación para refrescar todos los tokens
./auth.sh
```

> 💡 **Tip**: Solo proporciona los tokens de OAuth (`HYTALE_ACCESS_TOKEN`, `HYTALE_REFRESH_TOKEN`, `HYTALE_PROFILE_UUID`) en tu archivo `hytale_tokens.env`. Los tokens de sesión se refrescarán automáticamente en cada inicio del servidor!

---

## ⚙️ Configuración

### 📂 Estructura de archivos

```
hytale-docker/
├── 🐳 Dockerfile                      # Imagen del contenedor
├── 📦 docker-compose.yml               # Orquestación del servicio
├── 🔧 entrypoint.sh                    # Script de inicialización
├── 🔑 auth.sh                          # Script de autenticación OAuth2
├── 💎 hytale_tokens.env                # Tokens generados (creado automáticamente)
├── 📝 hytale_tokens.env.example        # Ejemplo de archivo de tokens
├── 📚 README.md                        # Documentación en inglés
├── 📚 README_ES.md                     # Esta documentación
├── 🔄 .github/
│   └── workflows/
│       └── docker-build.yml           # GitHub Actions workflow
└── 🗄️ hytale_data/                     # Datos del servidor (creado automáticamente)
    ├── Server/                         # Archivos del servidor
    │   ├── HytaleServer.jar
    │   ├── config.json
    │   └── ...
    ├── Assets.zip                      # Assets del juego
    ├── universe/                       # Mundos y saves
    ├── logs/                           # Logs del servidor
    └── .cache/                         # Cache optimizado
```

### 🔧 Variables de entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| `HYTALE_SERVER_SESSION_TOKEN` | Token de sesión del servidor (JWT, refrescado automáticamente) | - |
| `HYTALE_SERVER_IDENTITY_TOKEN` | Token de identidad del servidor (JWT, refrescado automáticamente) | - |
| `HYTALE_ACCESS_TOKEN` | OAuth access token (para auto-refresco) | - |
| `HYTALE_REFRESH_TOKEN` | OAuth refresh token (válido 30 días) | - |
| `HYTALE_PROFILE_UUID` | UUID del perfil para crear sesión | - |
| `WORKDIR` | Directorio de trabajo del servidor | `/app` |

### 🌐 Puertos

| Puerto | Protocolo | Descripción |
|--------|-----------|-------------|
| `5520` | UDP | Puerto por defecto del servidor Hytale (QUIC) |

> ⚠️ **Importante**: Hytale usa **QUIC sobre UDP**, no TCP. Asegúrate de configurar firewalls y port forwarding correctamente.
>
> 🔧 Para cambiar el puerto, modifica el archivo `docker-compose.yml` o usa la variable de entorno del servidor.

---

## 🛠️ Comandos útiles

```bash
# Ver logs del servidor en tiempo real
docker-compose logs -f

# Detener el servidor
docker-compose down

# Reconstruir la imagen desde cero
docker-compose build --no-cache

# Reiniciar el servidor
docker-compose restart

# Limpiar todos los datos del servidor (¡cuidado!)
rm -rf hytale_data/

# Verificar estado del contenedor
docker ps -a | grep hytale-server
```

---

## 📝 Notas importantes

<details>
<summary>🔒 Sobre la autenticación</summary>

- El servidor requiere autenticación para aceptar conexiones de jugadores
- Los tokens de sesión expiran cada hora y se **refrescan automáticamente** al iniciar el servidor si se proporcionan tokens OAuth
- Los refresh tokens de OAuth son válidos por 30 días - después necesitas volver a ejecutar `./auth.sh`
- El sistema de refresco automático usa el siguiente flujo:
  1. Servidor inicia → entrypoint verifica tokens OAuth
  2. Refresca el access token de OAuth usando refresh_token
  3. Crea nueva sesión de juego con el access_token fresco
  4. Guarda todos los nuevos tokens para el próximo reinicio
- El límite predeterminado es de **100 servidores concurrentes** por licencia de juego

</details>

<details>
<summary>💡 Sobre el rendimiento</summary>

- RAM mínima: **4GB** (recomendado 8GB+ para múltiples jugadores)
- El servidor usa protocolo **QUIC** para mejor rendimiento
- Considera limitar la `view distance` para reducir consumo de RAM
- Los assets se descargan solo la primera vez o cuando se actualizan

</details>

<details>
<summary>🔄 Sobre las actualizaciones</summary>

- Los archivos del servidor se mantienen en `hytale_data/`
- Para actualizar, borra `hytale_data/Server/` y reinicia el servidor
- Los mundos y configuraciones en `universe/` se conservan
- Los assets se verifican automáticamente al inicio

</details>

---

## 🔗 Recursos

- 🐳 [Docker Image](https://github.com/dogalyir/hytale-server-docker/pkgs/container/hytale-server-docker)
- 📚 [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- 🔐 [Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide)
- 🎮 [Hytale Official Website](https://hytale.com/)
- 💬 [Hytale Discord](https://discord.gg/hytale)

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

---

<div align="center">

**Hecho con ❤️ para la comunidad de Hytale**

[⬆ Volver al inicio](#-servidor-hytale-docker)

</div>
