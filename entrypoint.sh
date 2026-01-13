#!/bin/sh

WORKDIR=${WORKDIR:-/app}
TEMP_DIR=/tmp/hytale_downloader
TOKENS_DIR="${WORKDIR}/.tokens"
TOKENS_FILE="${TOKENS_DIR}/tokens.env"

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_warn() {
    echo "[WARN] $1" >&2
}

save_tokens() {
    mkdir -p "${TOKENS_DIR}"

    cat > "${TOKENS_FILE}" << EOF
# Hytale Server Authentication Tokens
# Auto-refreshed by entrypoint
# Last refresh: $(date -Iseconds)
HYTALE_ACCESS_TOKEN="${HYTALE_ACCESS_TOKEN}"
HYTALE_REFRESH_TOKEN="${HYTALE_REFRESH_TOKEN}"
HYTALE_PROFILE_UUID="${HYTALE_PROFILE_UUID}"
HYTALE_SERVER_SESSION_TOKEN="${HYTALE_SERVER_SESSION_TOKEN}"
HYTALE_SERVER_IDENTITY_TOKEN="${HYTALE_SERVER_IDENTITY_TOKEN}"
EOF

    log_info "Tokens saved to ${TOKENS_FILE}"
}

load_tokens() {
    if [ -f "${TOKENS_FILE}" ]; then
        log_info "Loading saved tokens from ${TOKENS_FILE}"
        . "${TOKENS_FILE}"
        return 0
    fi
    return 1
}

save_env_tokens_if_provided() {
    if [ -n "${HYTALE_ACCESS_TOKEN}" ] && [ -n "${HYTALE_REFRESH_TOKEN}" ] && [ -n "${HYTALE_PROFILE_UUID}" ]; then
        log_info "OAuth tokens provided via environment, saving to ${TOKENS_DIR}"
        save_tokens
    fi

    if [ -n "${HYTALE_SERVER_SESSION_TOKEN}" ] && [ -n "${HYTALE_SERVER_IDENTITY_TOKEN}" ]; then
        log_info "Session tokens provided via environment, saving to ${TOKENS_DIR}"
        save_tokens
    fi
}

refresh_oauth_token() {
    log_info "Refreshing OAuth access token..."

    response=$(curl -s -X POST "https://oauth.accounts.hytale.com/oauth2/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=hytale-server" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=${HYTALE_REFRESH_TOKEN}")

    error=$(echo "$response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)

    if [ -n "$error" ]; then
        log_error "Failed to refresh OAuth token: $error"
        log_error "Refresh token may be expired (valid for 30 days)"
        return 1
    fi

    export HYTALE_ACCESS_TOKEN=$(echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    export HYTALE_REFRESH_TOKEN=$(echo "$response" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$HYTALE_ACCESS_TOKEN" ]; then
        log_error "Failed to parse OAuth token response"
        return 1
    fi

    log_info "OAuth token refreshed successfully"
    save_tokens
    return 0
}

create_game_session() {
    log_info "Creating new game session..."

    response=$(curl -s -X POST "https://sessions.hytale.com/game-session/new" \
        -H "Authorization: Bearer ${HYTALE_ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"uuid\": \"${HYTALE_PROFILE_UUID}\"}")

    error=$(echo "$response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)

    if [ -n "$error" ]; then
        log_error "Failed to create game session: $error"
        return 1
    fi

    export HYTALE_SERVER_SESSION_TOKEN=$(echo "$response" | grep -o '"sessionToken":"[^"]*"' | cut -d'"' -f4)
    export HYTALE_SERVER_IDENTITY_TOKEN=$(echo "$response" | grep -o '"identityToken":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$HYTALE_SERVER_SESSION_TOKEN" ] || [ -z "$HYTALE_SERVER_IDENTITY_TOKEN" ]; then
        log_error "Failed to create game session"
        return 1
    fi

    log_info "Game session created successfully"
    save_tokens
    return 0
}

refresh_or_create_session() {
    if [ -n "${HYTALE_ACCESS_TOKEN}" ] && [ -n "${HYTALE_REFRESH_TOKEN}" ] && [ -n "${HYTALE_PROFILE_UUID}" ]; then
        log_info "OAuth tokens available, attempting to refresh session..."

        if ! refresh_oauth_token; then
            log_error "OAuth refresh failed. Tokens may be expired."
            return 1
        fi

        if ! create_game_session; then
            log_error "Failed to create game session"
            return 1
        fi

        return 0
    fi

    return 1
}

check_auth_tokens() {
    log_info "Checking authentication tokens..."

    if [ -n "${HYTALE_SERVER_SESSION_TOKEN}" ] && [ -n "${HYTALE_SERVER_IDENTITY_TOKEN}" ]; then
        log_info "Session tokens available from environment"
        save_env_tokens_if_provided
        return 0
    fi

    if load_tokens; then
        if [ -n "${HYTALE_ACCESS_TOKEN}" ] && [ -n "${HYTALE_REFRESH_TOKEN}" ]; then
            log_info "OAuth tokens found, attempting automatic refresh..."
            if refresh_or_create_session; then
                log_info "Session refreshed automatically!"
                return 0
            else
                log_warn "Automatic refresh failed, using existing session tokens if available"
                if [ -n "${HYTALE_SERVER_SESSION_TOKEN}" ] && [ -n "${HYTALE_SERVER_IDENTITY_TOKEN}" ]; then
                    return 0
                fi
            fi
        elif [ -n "${HYTALE_SERVER_SESSION_TOKEN}" ] && [ -n "${HYTALE_SERVER_IDENTITY_TOKEN}" ]; then
            log_info "Using existing session tokens"
            return 0
        fi
    fi

    return 1
}

download_hytale_assets() {
    log_info "Downloading Hytale assets..."
    mkdir -p "${TEMP_DIR}"
    cd "${TEMP_DIR}"

    log_info "Downloading hytale-downloader.zip..."
    curl -L -o hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip

    log_info "Extracting hytale-downloader.zip..."
    unzip -o hytale-downloader.zip
    chmod +x hytale-downloader-linux-amd64

    log_info "Running Hytale downloader..."
    ./hytale-downloader-linux-amd64 -download-path game.zip

    if [ ! -f "game.zip" ]; then
        log_error "game.zip was not created by the downloader"
        cleanup_temp_dir
        exit 1
    fi

    log_info "Extracting game.zip..."
    unzip -o game.zip

    if [ ! -f "Assets.zip" ]; then
        log_error "Assets.zip not found in game.zip"
        cleanup_temp_dir
        exit 1
    fi

    if [ ! -d "Server" ]; then
        log_error "Server directory not found in game.zip"
        cleanup_temp_dir
        exit 1
    fi

    log_info "Moving files to ${WORKDIR}..."
    mv Assets.zip "${WORKDIR}/"
    mv Server "${WORKDIR}/"

    cleanup_temp_dir
    log_info "Download and setup completed successfully"
}

cleanup_temp_dir() {
    cd /
    rm -rf "${TEMP_DIR}"
}

check_assets_exist() {
    if [ -f "${WORKDIR}/Assets.zip" ]; then
        log_info "Assets.zip already exists, skipping download"
        return 0
    fi
    return 1
}

print_auth_instructions() {
    echo ""
    echo "==================================================================================="
    echo "                         AUTHENTICATION REQUIRED"
    echo "==================================================================================="
    echo ""
    echo "No authentication tokens found. To authenticate your server:"
    echo ""
    echo "1. Run the authentication script on your host machine:"
    echo "   ./auth.sh"
    echo ""
    echo "2. Follow the instructions to authorize in your browser"
    echo ""
    echo "3. Copy the generated hytale_tokens.env to your deployment"
    echo ""
    echo "For Docker Compose:"
    echo "   docker-compose --env-file hytale_tokens.env up"
    echo ""
    echo "For Portainer:"
    echo "   Add the tokens as environment variables in your stack"
    echo ""
    echo "After the first authentication, tokens will be automatically refreshed!"
    echo "==================================================================================="
    echo ""
}

start_server() {
    log_info "Starting Hytale server..."

    local server_args="--assets ${WORKDIR}/Assets.zip"

    if [ -n "${HYTALE_SERVER_SESSION_TOKEN}" ] && [ -n "${HYTALE_SERVER_IDENTITY_TOKEN}" ]; then
        log_info "Starting in AUTHENTICATED mode"
        server_args="${server_args} --session-token ${HYTALE_SERVER_SESSION_TOKEN}"
        server_args="${server_args} --identity-token ${HYTALE_SERVER_IDENTITY_TOKEN}"
    else
        log_warn "Starting in OFFLINE mode - Players will not be able to connect"
        log_warn "To enable authentication, follow the instructions above"
    fi

    exec java -jar "${WORKDIR}/Server/HytaleServer.jar" ${server_args} "$@"
}

main() {
    if ! check_assets_exist; then
        download_hytale_assets
    fi

    if ! check_auth_tokens; then
        print_auth_instructions
    fi

    start_server
}

main
