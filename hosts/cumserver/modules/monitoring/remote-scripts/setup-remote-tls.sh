#!/bin/bash

# Setup TLS for remote node_exporter

set -e

PROMETHEUS_DIR="/etc/prometheus"
CERT_DIR="$PROMETHEUS_DIR/certs"
DOMAIN="${1:-$(hostname -f)}"
FORCE_REGENERATE="${2:-false}"

echo "Setting up TLS for node_exporter..."
echo "Domain: $DOMAIN"

# Create certificates directory
mkdir -p "$CERT_DIR"

# Generate self-signed certificate if it doesn't exist or if forced
if [ ! -f "$CERT_DIR/server.crt" ] || [ "$FORCE_REGENERATE" = "true" ]; then
    echo "Generating self-signed certificate..."
    
    # Create OpenSSL config for SAN (Subject Alternative Names)
    cat > "$CERT_DIR/openssl.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = Organization
OU = Monitoring
CN = $DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = $(hostname -I | awk '{print $1}')
EOF

    # Generate private key
    openssl genrsa -out "$CERT_DIR/server.key" 4096

    # Generate certificate
    openssl req -new -x509 -key "$CERT_DIR/server.key" \
        -out "$CERT_DIR/server.crt" \
        -days 365 \
        -config "$CERT_DIR/openssl.conf" \
        -extensions v3_req

    echo "Certificate generated successfully!"
else
    echo "Certificate already exists. Use 'true' as second parameter to regenerate."
fi

# Update web.yml to include TLS configuration
echo "Updating web.yml with TLS configuration..."

cat > "$PROMETHEUS_DIR/web.yml" << 'EOF'
# Basic authentication
basic_auth_users:
  prometheus:

# TLS configuration
tls_server_config:
  cert_file: /etc/prometheus/certs/server.crt
  key_file: /etc/prometheus/certs/server.key
  # Optional: specify TLS version
  min_version: TLS12
  max_version: TLS13
  # Optional: specify cipher suites (uncomment if needed)
  # cipher_suites:
  #   - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
  #   - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
EOF

# Set proper permissions
chown -R node_exporter:node_exporter "$PROMETHEUS_DIR"
chmod 600 "$CERT_DIR/server.key"
chmod 644 "$CERT_DIR/server.crt"
chmod 644 "$PROMETHEUS_DIR/web.yml"

# Update systemd service if needed
if systemctl is-active --quiet node_exporter; then
    echo "Restarting node_exporter service..."
    systemctl restart node_exporter
    
    # Wait a moment for service to start
    sleep 2
    
    # Check if service is running
    if systemctl is-active --quiet node_exporter; then
        echo "✅ Node exporter restarted successfully with TLS"
    else
        echo "❌ Failed to restart node_exporter"
        systemctl status node_exporter
        exit 1
    fi
else
    echo "Node exporter service is not running. Start it with: systemctl start node_exporter"
fi

echo ""
echo "🔒 TLS setup complete!"
echo ""
echo "Certificate details:"
openssl x509 -in "$CERT_DIR/server.crt" -noout -text | grep -A 10 "Subject:"
echo ""
echo "Test the TLS connection:"
echo "curl -k -u prometheus https://localhost:9100/metrics"
echo ""
echo "Or test from remote:"
echo "curl -k -u prometheus https://$(hostname -I | awk '{print $1}'):9100/metrics"
echo ""
echo "⚠️  Remember to:"
echo "1. Open port 9100 in your firewall"
echo "2. Update your NixOS configuration to enable TLS"
echo "3. Either use tlsInsecure = true or add the certificate to your monitoring server" 
