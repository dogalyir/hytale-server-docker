#!/bin/sh

WORKDIR=${WORKDIR:-/app}
TEMP_DIR=/tmp/hytale_downloader

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
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
    exec java -jar "${WORKDIR}/Server/HytaleServer.jar" --assets "${WORKDIR}/Assets.zip" "$@"
}

main() {
    if ! check_assets_exist; then
        download_hytale_assets
    fi

    start_server
}

main
