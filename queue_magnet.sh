#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
AUTH_CACHE_FILE="${SCRIPT_DIR}/auth.json"

function show_error_message() {
    text="$1"

    if command -v zenity &> /dev/null; then
        zenity --error --text="$text"
    else 
        logger -t "$0" "$text"
    fi
}

function read_token_cache() {
    # Try to load refresh token and secrets from cache file
    refresh_token=$(jq -r '.refresh_token' "$AUTH_CACHE_FILE" 2> /dev/null)
    client_id=$(jq -r '.client_id' "$AUTH_CACHE_FILE" 2> /dev/null)
    client_secret=$(jq -r '.client_secret' "$AUTH_CACHE_FILE" 2> /dev/null)

    if [ -z "${refresh_token}" ] || [ -z "${client_id}" ] || [ -z "${client_secret}" ]; then
        return
    fi

    # Get a new access token from the refresh token
    auth_resp=$(curl -X POST "https://api.real-debrid.com/oauth/v2/token" -d "client_id=${client_id}&client_secret=${client_secret}&code=${refresh_token}&grant_type=http://oauth.net/grant_type/device/1.0" 2> /dev/null)

    if [ -z "${auth_resp}" ]; then
        return
    fi

    echo "$auth_resp" | jq -r '.access_token'
}

function download_magnet () {
    url=$1
    token=$2
    # Queue the magnet
    id=$(curl -X POST -H "Authorization: Bearer ${token}" "https://api.real-debrid.com/rest/1.0/torrents/addMagnet" -d "magnet=${url}" 2> /dev/null | jq -r '.id')
    # Select all files if the download was queued successfully
    if [ -n "${id}" ] && [ "${id}" != "null" ]; then
        curl -X POST -H "Authorization: Bearer ${token}" "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/${id}" -d 'files=all' 2> /dev/null
        return 0
    else 
        return 1
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 magnets..."
    exit 1
fi

# Obtain OAUTH token
# Try to access cached auth data.
# Create and initialize the cache if not already created
token=$(read_token_cache)

if [ -z "${token}" ]; then
    show_error_message "Failed to obtain token. Try recreating the cache using the request_token.sh script. Make sure auth.json is placed into the same directory as the script or modify the AUTH_CACHE_FILE variable."
    exit 1
fi

for next_magnet in "$@"; do
    # Download each magnet link passed on the command line
    if ! download_magnet "$next_magnet" "$token"; then
        show_error_message "Failed to queue magnet $next_magnet"
    fi
done
