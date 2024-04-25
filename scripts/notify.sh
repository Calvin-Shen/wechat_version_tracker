#!/usr/bin/env bash

set -eo pipefail


GHTOKEN="${GHTOKEN:-}"
NETEASE_EMAIL="${NETEASE_EMAIL:-}"
NETEASE_PASSWORD="${NETEASE_PASSWORD:-}"
EMAIL_TO="${EMAIL_TO:-}"


function install_msmtp() {
    echo "Installing msmtp and dependencies..."
    apt-get update && apt-get install -y msmtp msmtp-mta ca-certificates
}

function configure_msmtp() {
    echo "Configuring msmtp..."
    cat > ~/.msmtprc <<EOF
defaults
auth           on
tls            on
tls_starttls   off
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

account        netease
host           smtp.163.com
port           465
from           $NETEASE_EMAIL
user           $NETEASE_EMAIL
password       $NETEASE_PASSWORD

account default : netease
EOF
    chmod 600 ~/.msmtprc
}

function send_email() {
    local subject="微信新版本发布通知"
    local body="$(prepare_email_body)"
    local mime_version="MIME-Version: 1.0"
    local content_type='Content-Type: text/plain; charset="UTF-8"'
    local content_transfer_encoding="Content-Transfer-Encoding: 8bit"

    echo "Sending email..."
    {
        echo "$mime_version"
        echo "$content_type"
        echo "$content_transfer_encoding"
        echo "Subject: $subject"
        echo ""
        echo "$body"
    } | msmtp -a default "$EMAIL_TO"
}

function prepare_email_body() {
    echo "Fetching latest release information from GitHub..."
    local release_info=$(gh release view --json body -q ".body" 2>&1)
    if [[ -z "$release_info" ]]; then
        echo "Failed to fetch release information or no information available."
        return 1
    fi
    echo "Release Details:"
    echo "$release_info"
}

function login_gh() {
    echo "Configuring safe directory for git operations..."
    git config --global --add safe.directory "$GITHUB_WORKSPACE"

    echo "Logging in to GitHub..."
    echo "$GHTOKEN" | gh auth login --with-token
}

function main() {
    login_gh
    configure_msmtp
    send_email
    echo "Logging out from GitHub..."
    gh auth logout
}

main