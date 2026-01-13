#!/bin/bash

TOKENS_FILE="${WORKDIR}/.tokens/tokens.env"
TOKENS_DIR="${WORKDIR}/.tokens"

check_tokens_file() {
    if [ ! -f "${TOKENS_FILE}" ]; then
        echo "❌ ERROR: No tokens file found at ${TOKENS_FILE}"
        echo ""
        echo "Run ./auth.sh to generate tokens"
        return 1
    fi
    return 0
}

decode_jwt_expiry() {
    local token=$1
    local payload=$(echo -n "$token" | cut -d. -f2)
    local decoded=$(echo "$payload" | base64 -d 2>/dev/null | echo -n)

    if [ -z "$decoded" ]; then
        echo "0"
        return 1
    fi

    local exp=$(echo "$decoded" | grep -o '"exp":[0-9]*' | cut -d':' -f2)

    if [ -z "$exp" ]; then
        echo "0"
        return 1
    fi

    echo "$exp"
    return 0
}

time_until_expiry() {
    local exp=$1
    local current=$(date +%s)
    local remaining=$((exp - current))

    if [ $remaining -le 0 ]; then
        echo "EXPIRED"
        return 1
    fi

    local hours=$((remaining / 3600))
    local minutes=$(((remaining % 3600) / 60))

    echo "${hours}h ${minutes}m"
    return 0
}

check_session_tokens() {
    echo "🔍 Checking session tokens..."

    local session_token=$(grep "HYTALE_SERVER_SESSION_TOKEN" "${TOKENS_FILE}" | cut -d'"' -f4)
    local identity_token=$(grep "HYTALE_SERVER_IDENTITY_TOKEN" "${TOKENS_FILE}" | cut -d'"' -f4)

    if [ -z "$session_token" ] || [ -z "$identity_token" ]; then
        echo "❌ ERROR: Session tokens not found in tokens file"
        return 1
    fi

    local session_exp=$(decode_jwt_expiry "$session_token")
    local identity_exp=$(decode_jwt_expiry "$identity_token")

    if [ "$session_exp" = "0" ] || [ "$identity_exp" = "0" ]; then
        echo "❌ ERROR: Failed to decode session tokens"
        return 1
    fi

    echo "✅ Session tokens found"

    local session_time=$(time_until_expiry "$session_exp")
    local identity_time=$(time_until_expiry "$identity_exp")

    echo "   Session token: $session_time remaining"
    echo "   Identity token: $identity_time remaining"

    if [ "$session_time" = "EXPIRED" ] || [ "$identity_time" = "EXPIRED" ]; then
        echo "⚠️  WARNING: Session tokens are EXPIRED"
        return 1
    fi

    return 0
}

check_oauth_tokens() {
    echo "🔍 Checking OAuth tokens..."

    local access_token=$(grep "HYTALE_ACCESS_TOKEN" "${TOKENS_FILE}" | cut -d'"' -f4)
    local refresh_token=$(grep "HYTALE_REFRESH_TOKEN" "${TOKENS_FILE}" | cut -d'"' -f4)

    if [ -z "$access_token" ] || [ -z "$refresh_token" ]; then
        echo "⚠️  WARNING: OAuth tokens not found in tokens file"
        return 1
    fi

    echo "✅ OAuth tokens found"

    local access_exp=$(decode_jwt_expiry "$access_token")

    if [ "$access_exp" = "0" ]; then
        echo "❌ ERROR: Failed to decode access token"
        return 1
    fi

    local access_time=$(time_until_expiry "$access_exp")
    echo "   Access token: $access_time remaining"
    echo "   Refresh token: Valid for 30 days from creation"

    if [ "$access_time" = "EXPIRED" ]; then
        echo "⚠️  WARNING: Access token is EXPIRED (can be refreshed with refresh_token)"
        return 1
    fi

    return 0
}

test_connection() {
    echo "🌐 Testing connection to Hytale services..."

    local session_token=$(grep "HYTALE_SERVER_SESSION_TOKEN" "${TOKENS_FILE}" | cut -d'"' -f4)

    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "https://sessions.hytale.com/game-session/new" \
        -H "Authorization: Bearer ${session_token}" \
        -H "Content-Type: application/json" \
        -d '{"test": "connection"}' \
        --max-time 5)

    if [ "$response" = "401" ]; then
        echo "❌ ERROR: Session token is INVALID"
        return 1
    elif [ "$response" = "403" ]; then
        echo "❌ ERROR: Session token is FORBIDDEN (invalid or expired)"
        return 1
    elif [ "$response" = "200" ] || [ "$response" = "400" ]; then
        echo "✅ Connection successful - Session token is VALID"
        return 0
    else
        echo "⚠️  WARNING: Unexpected HTTP response: $response"
        return 1
    fi
}

print_health_status() {
    echo ""
    echo "==================================================================================="
    echo "                        HYTALE TOKEN STATUS"
    echo "==================================================================================="
    echo ""
    echo "📂 Tokens file: ${TOKENS_FILE}"
    echo ""
    local file_age=0
    if [ -f "${TOKENS_FILE}" ]; then
        local file_mtime=$(stat -c %Y "${TOKENS_FILE}" 2>/dev/null || stat -f %m "${TOKENS_FILE}")
        local current_time=$(date +%s)
        file_age=$((current_time - file_mtime))

        local hours=$((file_age / 3600))
        local minutes=$(((file_age % 3600) / 60))

        echo "🕐 Last refresh: ${hours}h ${minutes}m ago"
    fi
    echo ""
    echo "==================================================================================="
    echo ""
}

print_summary() {
    if [ $? -eq 0 ]; then
        echo "✅ All checks passed - Tokens are valid!"
        echo ""
        echo "💡 Tips:"
        echo "   - Session tokens will be automatically refreshed on server start"
        echo "   - OAuth tokens are valid for 30 days"
        echo "   - Run ./auth.sh again after 30 days to refresh OAuth tokens"
    else
        echo "❌ Some checks failed - See warnings above"
        echo ""
        echo "🔧 To fix:"
        echo "   1. Run ./auth.sh to generate new tokens"
        echo "   2. Restart your server: docker-compose restart"
    fi
    echo ""
}

main() {
    WORKDIR=${1:-/app}

    if ! check_tokens_file; then
        exit 1
    fi

    print_health_status

    local session_valid=0
    local oauth_valid=0

    if check_session_tokens; then
        session_valid=1
    fi

    echo ""
    check_oauth_tokens

    if [ $session_valid -eq 1 ]; then
        echo ""
        test_connection
    fi

    print_summary
}

main "$@"
