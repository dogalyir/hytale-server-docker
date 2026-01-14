# 🎮 Hytale Docker Server

<div align="center">

![Status](https://img.shields.io/badge/status-working-success)
![License](https://img.shields.io/badge/license-MIT-blue)
![Docker](https://img.shields.io/badge/docker-supported-blue)
![Platform](https://img.shields.io/badge/platform-linux%2Famd64-orange)

**Hytale server in Docker container with automatic asset download and OAuth2 authentication support**

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Configuration](#-configuration)

[🇪🇸 Leer en español](README_ES.md) • [💬 Join Discord](https://discord.gg/EPnFKFsMq8)

</div>

---

## 📋 Status

> ✅ **Working & Production Ready**

This project is fully functional and ready for production use. All features are working as intended.

## ✨ Features

- 🚀 **Automatic download** of Hytale assets using the official CLI
- 🔐 **OAuth2 authentication** via Device Code Flow
- 🔄 **Automatic token refresh** - Session tokens refresh on every server start
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
# ghcr.io/dogalyir/hytale-server-docker:main
# This will automatically be built on GitHub Container Registry when you push to main

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

#### 🔄 Automatic token refresh & management

> ⚡ **Automatic token management** - The server handles everything for you!

**How it works:**

1. **First time setup**: Run `./auth.sh` once to generate tokens
2. **Automatic saving**: Tokens are automatically saved to `hytale_data/.tokens/tokens.env`
3. **Automatic refresh**: On every server start, the entrypoint:
   - Loads saved tokens from `hytale_data/.tokens/`
   - Refreshes the OAuth access token using the refresh token
   - Creates a new game session with the refreshed access token
   - Saves all updated tokens
4. **Continuous operation**: You don't need to worry about refreshing tokens!

**Token expiration:**

| Token Type | Expiration | Auto-refreshed? |
|------------|------------|------------------|
| OAuth Access Token | 1 hour | ✅ Yes |
| OAuth Refresh Token | 30 days | ❌ No (run `./auth.sh`) |
| Game Session | 1 hour | ✅ Yes (on server start) |

**Manual refresh (if needed):**

```bash
# Re-run the auth script to refresh all tokens (every 30 days)
./auth.sh
```

**Check token status:**

```bash
# Verify token validity and check expiration
./check-tokens.sh

# Or check tokens in a running container
docker exec hytale-server /check-tokens.sh
```

> 💡 **Best practice**: Provide OAuth tokens (`HYTALE_ACCESS_TOKEN`, `HYTALE_REFRESH_TOKEN`, `HYTALE_PROFILE_UUID`) once. The server will automatically save them to `hytale_data/.tokens/` and refresh session tokens on every start!

---

## ⚙️ Configuration

### 📂 File structure

```
hytale-docker/
├── 🐳 Dockerfile                      # Container image
├── 📦 docker-compose.yml               # Service orchestration
├── 🔧 entrypoint.sh                    # Initialization script
├── 🔐 auth.sh                        # OAuth2 authentication script
├── 🔍 check-tokens.sh                # Token verification script
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
    ├── .cache/                         # Optimized cache
    └── .tokens/                        # Auto-refreshed tokens (created by entrypoint)
        └── tokens.env                  # Saved OAuth and session tokens
```

### 🔧 Environment variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HYTALE_SERVER_SESSION_TOKEN` | Server session token (JWT, auto-refreshed) | - |
| `HYTALE_SERVER_IDENTITY_TOKEN` | Server identity token (JWT, auto-refreshed) | - |
| `HYTALE_ACCESS_TOKEN` | OAuth access token (for auto-refresh) | - |
| `HYTALE_REFRESH_TOKEN` | OAuth refresh token (valid 30 days) | - |
| `HYTALE_PROFILE_UUID` | Profile UUID for session creation | - |
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
- Session tokens expire every hour and are **automatically refreshed** on server start if OAuth tokens are provided
- OAuth refresh tokens are valid for 30 days - after that, you need to re-run `./auth.sh`
- The automatic refresh system uses the following flow:
  1. Server starts → entrypoint checks for OAuth tokens
  2. Refreshes OAuth access token using refresh_token
  3. Creates new game session with fresh access token
  4. Saves all new tokens for next restart
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

- 🐳 [Docker Image](https://github.com/dogalyir/hytale-server-docker/pkgs/container/hytale-server-docker)
- 📚 [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- 🔐 [Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide)
- 🎮 [Hytale Official Website](https://hytale.com/)
- 💬 [Hytale Official Discord](https://discord.gg/hytale)
- 🤝 [Join our Community Discord](https://discord.gg/EPnFKFsMq8)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Made with ❤️ for the Hytale community**

[⬆ Back to top](#-hytale-docker-server)

</div>
