#!/bin/bash

set -e

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

request_device_code() {
    log_info "Requesting device code..."
    response=$(curl -s -X POST "https://oauth.accounts.hytale.com/oauth2/device/auth" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=hytale-server" \
        -d "scope=openid offline auth:server")

    DEVICE_CODE=$(echo "$response" | grep -o '"device_code":"[^"]*"' | cut -d'"' -f4)
    USER_CODE=$(echo "$response" | grep -o '"user_code":"[^"]*"' | cut -d'"' -f4)
    VERIFICATION_URI=$(echo "$response" | grep -o '"verification_uri":"[^"]*"' | cut -d'"' -f4)
    INTERVAL=$(echo "$response" | grep -o '"interval":[0-9]*' | cut -d':' -f2)

    if [ -z "$DEVICE_CODE" ] || [ -z "$USER_CODE" ] || [ -z "$VERIFICATION_URI" ]; then
        log_error "Failed to parse device code response"
        echo "Response: $response"
        exit 1
    fi

    log_info "Device code received successfully"
}

display_auth_instructions() {
    echo ""
    echo "==================================================================="
    echo "                   DEVICE AUTHORIZATION"
    echo "==================================================================="
    echo "Visit: $VERIFICATION_URI"
    echo "Enter code: $USER_CODE"
    echo "Or visit: ${VERIFICATION_URI}?user_code=${USER_CODE}"
    echo "==================================================================="
    echo ""
}

poll_for_token() {
    local interval=${INTERVAL:-5}
    local max_attempts=180
    local attempt=0

    log_info "Polling for authorization token..."
    log_info "Please complete authorization in your browser within 15 minutes"

    while [ $attempt -lt $max_attempts ]; do
        response=$(curl -s -X POST "https://oauth.accounts.hytale.com/oauth2/token" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "client_id=hytale-server" \
            -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
            -d "device_code=${DEVICE_CODE}")

        error=$(echo "$response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)

        if [ "$error" = "authorization_pending" ]; then
            log_info "Waiting for authorization... (${interval}s interval)"
            sleep $interval
            attempt=$((attempt + 1))
        elif [ "$error" = "slow_down" ]; then
            interval=$((interval + 5))
            log_info "Slow down received, increasing interval to ${interval}s"
            sleep $interval
            attempt=$((attempt + 1))
        elif [ "$error" = "expired_token" ]; then
            log_error "Device code has expired, please try again"
            exit 1
        elif [ "$error" = "access_denied" ]; then
            log_error "Authorization was denied"
            exit 1
        elif [ -z "$error" ]; then
            ACCESS_TOKEN=$(echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
            REFRESH_TOKEN=$(echo "$response" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)
            EXPIRES_IN=$(echo "$response" | grep -o '"expires_in":[0-9]*' | cut -d':' -f2)

            if [ -z "$ACCESS_TOKEN" ] || [ -z "$REFRESH_TOKEN" ]; then
                log_error "Failed to parse token response"
                echo "Response: $response"
                exit 1
            fi

            log_info "Authorization successful!"
            log_info "Access token expires in ${EXPIRES_IN} seconds"
            return
        else
            log_error "Unknown error: $error"
            echo "Response: $response"
            exit 1
        fi
    done

    log_error "Authorization timed out after 15 minutes"
    exit 1
}

get_profiles() {
    log_info "Fetching available profiles..."
    response=$(curl -s -X GET "https://account-data.hytale.com/my-account/get-profiles" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}")

    PROFILE_UUID=$(echo "$response" | grep -o '"uuid":"[^"]*"' | head -1 | cut -d'"' -f4)
    PROFILE_USERNAME=$(echo "$response" | grep -o '"username":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$PROFILE_UUID" ]; then
        log_error "Failed to parse profiles response"
        echo "Response: $response"
        exit 1
    fi

    log_info "Selected profile: $PROFILE_USERNAME ($PROFILE_UUID)"
}

create_game_session() {
    log_info "Creating game session..."
    response=$(curl -s -X POST "https://sessions.hytale.com/game-session/new" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"uuid\": \"${PROFILE_UUID}\"}")

    SESSION_TOKEN=$(echo "$response" | grep -o '"sessionToken":"[^"]*"' | cut -d'"' -f4)
    IDENTITY_TOKEN=$(echo "$response" | grep -o '"identityToken":"[^"]*"' | cut -d'"' -f4)
    EXPIRES_AT=$(echo "$response" | grep -o '"expiresAt":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$SESSION_TOKEN" ] || [ -z "$IDENTITY_TOKEN" ]; then
        log_error "Failed to create game session"
        echo "Response: $response"
        exit 1
    fi

    log_info "Game session created successfully!"
    log_info "Session expires at: $EXPIRES_AT"
}

save_tokens() {
    local token_file="${TOKEN_FILE:-./hytale_tokens.env}"

    log_info "Saving tokens to $token_file..."

    cat > "$token_file" << EOF
# Hytale Server Authentication Tokens
# Generated: $(date -Iseconds)
# Session expires at: $EXPIRES_AT

HYTALE_SERVER_SESSION_TOKEN="${SESSION_TOKEN}"
HYTALE_SERVER_IDENTITY_TOKEN="${IDENTITY_TOKEN}"

# OAuth tokens for refresh (valid for 30 days)
HYTALE_ACCESS_TOKEN="${ACCESS_TOKEN}"
HYTALE_REFRESH_TOKEN="${REFRESH_TOKEN}"
HYTALE_PROFILE_UUID="${PROFILE_UUID}"
EOF

    log_info "Tokens saved to $token_file"
    log_info "To load these tokens: source $token_file"
}

main() {
    log_info "Starting Hytale Server Authentication (Device Code Flow)"
    log_info ""

    request_device_code
    display_auth_instructions
    poll_for_token
    get_profiles
    create_game_session
    save_tokens

    log_info ""
    log_info "Authentication complete!"
    log_info "Start the server with:"
    log_info "  docker-compose --env-file hytale_tokens.env up"
    log_info "Or manually:"
    log_info "  export HYTALE_SERVER_SESSION_TOKEN='...'"
    log_info "  export HYTALE_SERVER_IDENTITY_TOKEN='...'"
    log_info "  docker-compose up"
}

main "$@"
