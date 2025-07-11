#!/bin/bash

# Setup script for remote node_exporter with basic authentication
# This script should be run on the remote server (45.144.51.68)

set -e

echo "Setting up node_exporter with basic authentication..."

apt-get update
apt-get install -y python3-bcrypt wget

# Create node_exporter user
useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || echo "User node_exporter already exists"

# Download and install node_exporter
NODE_EXPORTER_VERSION="1.9.1"
cd /tmp
wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
tar -xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create prometheus directory
mkdir -p /etc/prometheus
chmod 755 /etc/prometheus

# Generate password hash
echo "Please enter a password for the prometheus user:"
python3 -c "
import getpass
import bcrypt
password = getpass.getpass('password: ')
hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
print('Generated hash:', hashed.decode())
with open('/etc/prometheus/web.yml', 'w') as f:
    f.write(f'''basic_auth_users:
  prometheus: {hashed.decode()}
''')
print('Password hash saved to /etc/prometheus/web.yml')
"

# Create systemd service file
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
    --web.config.file=/etc/prometheus/web.yml \
    --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R node_exporter:node_exporter /etc/prometheus

# Enable and start service
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "Node exporter has been installed and started with basic authentication!"
echo "It's listening on port 9100 with username 'prometheus'"
echo "Make sure to:"
echo "1. Update the password in your NixOS secrets/remoteNodePassword file"
echo "2. Open port 9100 in your firewall if needed"
echo "3. Test the connection with: curl -u prometheus http://localhost:9100/metrics"

echo "Setup complete!" 