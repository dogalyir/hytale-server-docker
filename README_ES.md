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
# Cambia ghcr.io/YOUR_USERNAME/your-repo:main
# Por tu repositorio real, ejemplo: ghcr.io/johndoe/hytale-docker:main

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

#### 🔄 Refrescar tokens

Los tokens de sesión expiran en **1 hora**, los refresh tokens en **30 días**:

```bash
# Refrescar tokens (usa refresh_token guardado)
./auth.sh
```

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
| `HYTALE_SERVER_SESSION_TOKEN` | Token de sesión del servidor (JWT) | - |
| `HYTALE_SERVER_IDENTITY_TOKEN` | Token de identidad del servidor (JWT) | - |
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
- Los tokens de sesión expiran cada hora, el servidor intenta refrescarlos automáticamente
- Para producción, considera implementar refresco automático de tokens
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

- 🐳 [Docker Image](https://github.com/YOUR_USERNAME/your-repo/pkgs/container/your-repo)
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
