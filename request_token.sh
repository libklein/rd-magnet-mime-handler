#!/usr/bin/env bash

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace       # Trace the execution of the script (debug)
fi

# Only enable these shell behaviours if we're not being sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    # A better class of script...
    set -o errexit      # Exit on most errors (see the manual)
    set -o nounset      # Disallow expansion of unset variables
    set -o pipefail     # Use last non-zero exit code in a pipeline
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace         # Ensure the error trap handler is inherited

SCRIPT_DIR=$(basename "$0")

# Real Debrid client ID for opensource apps
CLIENT_ID=${1-"X245A4XAIBGVM"}

# Request new OAUTH tokens
AUTH_REQ_DATA=$(curl "https://api.real-debrid.com/oauth/v2/device/code?client_id=${CLIENT_ID}&new_credentials=yes" 2> /dev/null)
# Parse response
device_code=$(echo "$AUTH_REQ_DATA" | jq -r '.device_code')
user_code=$(echo "$AUTH_REQ_DATA" | jq -r '.user_code')
url=$(echo "$AUTH_REQ_DATA" | jq -r '.direct_verification_url')
interval=$(echo "$AUTH_REQ_DATA" | jq -r '.interval')
expires=$(echo "$AUTH_REQ_DATA" | jq -r '.expires_in')

echo "Enter code ${user_code} at ${url}"

auth_wait_start_time=$SECONDS
client_secret=""
# Wait until the code has been unlocked
while [ $((SECONDS - auth_wait_start_time)) -lt "$expires" ]; do
    credentials=$(curl "https://api.real-debrid.com/oauth/v2/device/credentials?client_id=${CLIENT_ID}&code=${device_code}" 2> /dev/null)
    if [ "$(echo "$credentials" | jq -e '.client_secret')" != "null" ]; then
        client_secret=$(echo "$credentials" | jq -r '.client_secret')
        CLIENT_ID=$(echo "$credentials" | jq -r '.client_id')
        break
    fi
    sleep "$interval"
done

if [ -z "${client_secret}" ]; then
    echo "Could not receive client secret as the auth request timed out!"
    exit 1
fi

# Get a refresh token
tokens=$(curl -X POST "https://api.real-debrid.com/oauth/v2/token" -d "client_id=${CLIENT_ID}&code=${device_code}&client_secret=${client_secret}&grant_type=http://oauth.net/grant_type/device/1.0" 2> /dev/null)
refresh_token=$(echo "$tokens" | jq -r '.refresh_token')

if [ -z "${refresh_token}" ]; then 
    echo "Failed to obtain refresh token: ${tokens}"
fi

# Write obtained token, client id, and secret to auth.json
cat << EOF > "$SCRIPT_DIR/auth.json"
{
    "refresh_token": "$refresh_token",
    "client_id": "$CLIENT_ID",
    "client_secret": "$client_secret"
}
EOF

echo "Saved tokens to \"$SCRIPT_DIR/auth.json\""

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
