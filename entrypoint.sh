#!/bin/sh

WORKDIR=${WORKDIR:-/app}
TEMP_DIR=/tmp/hytale_downloader
TOKENS_DIR="${WORKDIR}/.tokens"

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
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

save_tokens() {
    mkdir -p "${TOKENS_DIR}"

    cat > "${TOKENS_DIR}/tokens.env" << EOF
# Hytale Server Authentication Tokens
# Automatically refreshed by entrypoint
HYTALE_ACCESS_TOKEN="${HYTALE_ACCESS_TOKEN}"
HYTALE_REFRESH_TOKEN="${HYTALE_REFRESH_TOKEN}"
HYTALE_PROFILE_UUID="${HYTALE_PROFILE_UUID}"
HYTALE_SERVER_SESSION_TOKEN="${HYTALE_SERVER_SESSION_TOKEN}"
HYTALE_SERVER_IDENTITY_TOKEN="${HYTALE_SERVER_IDENTITY_TOKEN}"
EOF
}

load_tokens() {
    if [ -f "${TOKENS_DIR}/tokens.env" ]; then
        log_info "Loading saved tokens..."
        . "${TOKENS_DIR}/tokens.env"
        return 0
    fi
    return 1
}

refresh_or_create_session() {
    if [ -n "${HYTALE_REFRESH_TOKEN}" ] && [ -n "${HYTALE_ACCESS_TOKEN}" ] && [ -n "${HYTALE_PROFILE_UUID}" ]; then
        log_info "OAuth tokens available, attempting to refresh session..."

        if ! refresh_oauth_token; then
            log_error "Failed to refresh OAuth token. Please re-run ./auth.sh"
            return 1
        fi

        if ! create_game_session; then
            log_error "Failed to create game session. Please re-run ./auth.sh"
            return 1
        fi

        return 0
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

start_server() {
    log_info "Starting Hytale server..."

    local server_args="--assets ${WORKDIR}/Assets.zip"

    if [ -n "${HYTALE_SERVER_SESSION_TOKEN}" ] && [ -n "${HYTALE_SERVER_IDENTITY_TOKEN}" ]; then
        log_info "Authentication tokens available, starting in authenticated mode"
        server_args="${server_args} --session-token ${HYTALE_SERVER_SESSION_TOKEN}"
        server_args="${server_args} --identity-token ${HYTALE_SERVER_IDENTITY_TOKEN}"
    else
        log_info "No authentication tokens provided, starting in offline mode"
    fi

    exec java -jar "${WORKDIR}/Server/HytaleServer.jar" ${server_args} "$@"
}

main() {
    if ! check_assets_exist; then
        download_hytale_assets
    fi

    if [ -n "${HYTALE_SERVER_SESSION_TOKEN}" ] || [ -n "${HYTALE_SERVER_IDENTITY_TOKEN}" ]; then
        if load_tokens && refresh_or_create_session; then
            log_info "Session refreshed successfully"
        else
            log_info "Using provided session tokens"
        fi
    elif load_tokens; then
        refresh_or_create_session
    fi

    start_server
}

main
