# 🎮 Hytale Docker Server

<div align="center">

![Status](https://img.shields.io/badge/status-dev-yellow)
![License](https://img.shields.io/badge/license-MIT-blue)
![Docker](https://img.shields.io/badge/docker-supported-blue)
![Platform](https://img.shields.io/badge/platform-linux%2Famd64-orange)

**Hytale server in Docker container with automatic asset download and OAuth2 authentication support**

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Configuration](#-configuration)

[🇪🇸 Leer en español](README_ES.md)

</div>

---

## 📋 Status

> 🚧 **Under Development**

This project is currently in development. Configuration and features may change significantly.

## ✨ Features

- 🚀 **Automatic download** of Hytale assets using the official CLI
- 🔐 **OAuth2 authentication** via Device Code Flow
- 💾 **Data persistence** using Docker volumes
- ⚡ **Smart caching** - Only downloads when necessary
- 🧹 **Automatic cleanup** of temporary files
- 🔄 **Flexible modes** - Offline or Authenticated
- 🏗️ **Multi-architecture** - Support for x86_64 and ARM64

---

## 📦 Requirements

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| Docker | 20.10+ | [Install](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.0+ | [Install](https://docs.docker.com/compose/install/) |
| macOS | Apple Silicon | Requires x86_64 emulation |

---

## 🚀 Installation

### Option A: Use published image (recommended)

```bash
# Clone the repository
git clone <repo-url>
cd HytaleDocker

# Important: Modify docker-compose.yml to use your image
# Change ghcr.io/YOUR_USERNAME/your-repo:main
# To your actual repository, e.g., ghcr.io/johndoe/hytale-docker:main

# Start the server
docker-compose up -d
```

> 💡 **Tip**: The image is automatically built on GitHub Container Registry every time you push to the `main` branch.

### Option B: Build locally

```bash
# Clone the repository
git clone <repo-url>
cd HytaleDocker

# Uncomment the 'build: .' line in docker-compose.yml
# Comment out the 'image: ...' line

# Build and start
docker-compose up -d --build
```

## 🎯 Usage

### 1️⃣ Offline Mode (no authentication)

For local testing without connection to Hytale services:

```bash
docker-compose up -d
```

### 2️⃣ Authenticated Mode (OAuth2 Device Code Flow)

For production and player connections:

#### 📝 Step 1: Get authentication tokens

```bash
# Run the interactive authentication script
./auth.sh
```

<details>
<summary>📖 What does the script do?</summary>

The `auth.sh` script automates the entire OAuth2 Device Code Flow process:

1. 🔄 Requests a `device_code` from Hytale OAuth servers
2. 🌐 Displays URL and code for browser authorization
3. ⏳ Waits for you to complete authorization (up to 15 min)
4. 🎉 Obtains `access_token` and `refresh_token`
5. 🎮 Creates a game session via API
6. 💾 Saves tokens to `hytale_tokens.env`

</details>

#### 🚀 Step 2: Start authenticated server

```bash
# Load tokens and start the server
docker-compose --env-file hytale_tokens.env up -d
```

#### 🔄 Refresh tokens

Session tokens expire after **1 hour**, refresh tokens after **30 days**:

```bash
# Refresh tokens (uses saved refresh_token)
./auth.sh
```

---

## ⚙️ Configuration

### 📂 File structure

```
hytale-docker/
├── 🐳 Dockerfile                      # Container image
├── 📦 docker-compose.yml               # Service orchestration
├── 🔧 entrypoint.sh                    # Initialization script
├── 🔑 auth.sh                          # OAuth2 authentication script
├── 💎 hytale_tokens.env                # Generated tokens (created automatically)
├── 📝 hytale_tokens.env.example        # Token file example
├── 📚 README.md                        # This documentation
├── 📚 README_ES.md                     # Spanish documentation
├── 🔄 .github/
│   └── workflows/
│       └── docker-build.yml           # GitHub Actions workflow
└── 🗄️ hytale_data/                     # Server data (created automatically)
    ├── Server/                         # Server files
    │   ├── HytaleServer.jar
    │   ├── config.json
    │   └── ...
    ├── Assets.zip                      # Game assets
    ├── universe/                       # Worlds and saves
    ├── logs/                           # Server logs
    └── .cache/                         # Optimized cache
```

### 🔧 Environment variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HYTALE_SERVER_SESSION_TOKEN` | Server session token (JWT) | - |
| `HYTALE_SERVER_IDENTITY_TOKEN` | Server identity token (JWT) | - |
| `WORKDIR` | Server working directory | `/app` |

### 🌐 Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `5520` | UDP | Default Hytale server port (QUIC) |

> ⚠️ **Important**: Hytale uses **QUIC over UDP**, not TCP. Make sure to configure firewalls and port forwarding correctly.
>
> 🔧 To change the port, modify the `docker-compose.yml` file or use the server's environment variable.

---

## 🛠️ Useful commands

```bash
# View server logs in real-time
docker-compose logs -f

# Stop the server
docker-compose down

# Rebuild image from scratch
docker-compose build --no-cache

# Restart the server
docker-compose restart

# Clean all server data (careful!)
rm -rf hytale_data/

# Check container status
docker ps -a | grep hytale-server
```

---

## 📝 Important notes

<details>
<summary>🔒 About authentication</summary>

- The server requires authentication to accept player connections
- Session tokens expire every hour, the server attempts to refresh them automatically
- For production, consider implementing automatic token refresh
- Default limit is **100 concurrent servers** per game license

</details>

<details>
<summary>💡 About performance</summary>

- Minimum RAM: **4GB** (8GB+ recommended for multiple players)
- The server uses **QUIC** protocol for better performance
- Consider limiting `view distance` to reduce RAM usage
- Assets are downloaded only the first time or when updated

</details>

<details>
<summary>🔄 About updates</summary>

- Server files are kept in `hytale_data/`
- To update, delete `hytale_data/Server/` and restart the server
- Worlds and configurations in `universe/` are preserved
- Assets are automatically verified on startup

</details>

---

## 🔗 Resources

- 🐳 [Docker Image](https://github.com/YOUR_USERNAME/your-repo/pkgs/container/your-repo)
- 📚 [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- 🔐 [Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide)
- 🎮 [Hytale Official Website](https://hytale.com/)
- 💬 [Hytale Discord](https://discord.gg/hytale)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Made with ❤️ for the Hytale community**

[⬆ Back to top](#-hytale-docker-server)

</div>
