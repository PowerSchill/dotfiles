#!/usr/bin/env zsh

# API keys - set these in your shell environment or .zshrc.local
: ${IPGEOLOCATION_API_KEY:=""}
: ${SECURITYTRAILS_API_KEY:=""}

# Get public IP address
function myip() {
    local ip
    ip=$(curl -s https://api.ipify.org) || ip=$(curl -s https://ifconfig.me)
    if [[ -n "$ip" ]]; then
        echo "Your public IP: $ip"
    else
        echo "Error: Could not retrieve public IP"
        return 1
    fi
}

# Get geolocation information for an IP address
function whereip() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: whereip <ip_address>"
        return 1
    fi

    if [[ -z "$IPGEOLOCATION_API_KEY" ]]; then
        echo "Error: IPGEOLOCATION_API_KEY not set"
        echo "Set it in your environment: export IPGEOLOCATION_API_KEY='your_key'"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required but not installed"
        return 1
    fi

    curl -s "https://api.ipgeolocation.io/ipgeo?apiKey=${IPGEOLOCATION_API_KEY}&ip=$1" | jq '.'
}

# Get domain information from SecurityTrails
function whothat() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: whothat <domain>"
        return 1
    fi

    if [[ -z "$SECURITYTRAILS_API_KEY" ]]; then
        echo "Error: SECURITYTRAILS_API_KEY not set"
        echo "Set it in your environment: export SECURITYTRAILS_API_KEY='your_key'"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required but not installed"
        return 1
    fi

    curl -s "https://api.securitytrails.com/v1/domain/$1" \
        -H "apikey: ${SECURITYTRAILS_API_KEY}" | jq '.'
}

# Get WHOIS history from SecurityTrails
function whohist() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: whohist <domain>"
        return 1
    fi

    if [[ -z "$SECURITYTRAILS_API_KEY" ]]; then
        echo "Error: SECURITYTRAILS_API_KEY not set"
        echo "Set it in your environment: export SECURITYTRAILS_API_KEY='your_key'"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required but not installed"
        return 1
    fi

    curl -s "https://api.securitytrails.com/v1/history/$1/whois?apikey=${SECURITYTRAILS_API_KEY}" | jq '.'
}

# Check SSL/TLS certificate details
function sslcheck() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: sslcheck <hostname[:port]>"
        echo "Example: sslcheck example.com"
        echo "         sslcheck example.com:8443"
        return 1
    fi

    if ! command -v openssl &>/dev/null; then
        echo "Error: openssl is required but not installed"
        return 1
    fi

    local host="${1%%:*}"
    local port="${1#*:}"
    [[ "$port" == "$host" ]] && port=443

    echo | openssl s_client -servername "$host" -connect "${host}:${port}" 2>/dev/null | \
        openssl x509 -noout -issuer -subject -dates
}

# Get detailed TLS certificate information
function show_cert() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: show_cert <hostname[:port]>"
        echo "Example: show_cert example.com"
        return 1
    fi

    if ! command -v openssl &>/dev/null; then
        echo "Error: openssl is required but not installed"
        return 1
    fi

    local host="${1%%:*}"
    local port="${1#*:}"
    [[ "$port" == "$host" ]] && port=443

    echo "=== DNS Lookup ==="
    if command -v nslookup &>/dev/null; then
        nslookup "$host"
    elif command -v dig &>/dev/null; then
        dig +short "$host"
    else
        echo "No DNS lookup tool available"
    fi

    echo -e "\n=== Certificate Validity ==="
    openssl s_client -showcerts -servername "$host" -connect "${host}:${port}" <<<"Q" 2>/dev/null | \
        openssl x509 -text 2>/dev/null | grep -iA2 "Validity"

    echo -e "\n=== Certificate Subject ==="
    openssl s_client -showcerts -servername "$host" -connect "${host}:${port}" <<<"Q" 2>/dev/null | \
        openssl x509 -text 2>/dev/null | grep -iA1 "Subject:"
}

# Simple DNS lookup
function dns_lookup() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: dns_lookup <hostname>"
        return 1
    fi

    if command -v dig &>/dev/null; then
        dig "$1" +short
    elif command -v nslookup &>/dev/null; then
        nslookup "$1"
    else
        echo "Error: No DNS lookup tool available (dig or nslookup required)"
        return 1
    fi
}

# Test port connectivity
function port_test() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: port_test <hostname> <port>"
        echo "Example: port_test example.com 443"
        return 1
    fi

    local host="$1"
    local port="$2"

    if command -v nc &>/dev/null; then
        if nc -zv -w3 "$host" "$port" 2>&1 | grep -q "succeeded\|open"; then
            echo "✓ Port $port on $host is open"
            return 0
        else
            echo "✗ Port $port on $host is closed or unreachable"
            return 1
        fi
    elif command -v timeout &>/dev/null; then
        if timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            echo "✓ Port $port on $host is open"
            return 0
        else
            echo "✗ Port $port on $host is closed or unreachable"
            return 1
        fi
    else
        echo "Error: nc (netcat) or timeout command required"
        return 1
    fi
}
