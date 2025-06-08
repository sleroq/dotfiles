# Bore Module Quick Start Guide

## What was added

1. **Bore Module** (`modules/bore.nix`): A NixOS module that wraps bore-cli and provides:
   - Automatic systemd service creation for each tunnel
   - Caddy reverse proxy integration
   - Support for multiple tunnels with different configurations

2. **Caddy Integration**: Updated Caddy module to support bore.cum.army subdomains

3. **Configuration**: Added bore module to the main configuration with examples

## How to use

### 1. Enable a tunnel

Edit `configuration.nix` and enable a tunnel:

```nix
cumserver.bore.tunnels = {
  test = {
    enable = true;  # Change from false to true
    localPort = 8000;
    caddy.enable = true;
    caddy.domain = "test.bore.cum.army";
  };
};
```

### 2. Deploy the configuration

```bash
sudo nixos-rebuild switch --flake .
```

### 3. Check the tunnel status

```bash
# Check if the bore service is running
systemctl status bore-test

# View logs
journalctl -u bore-test -f

# Check if Caddy picked up the configuration
systemctl status caddy
```

### 4. Test the tunnel

1. Start a local service on port 8000:
   ```bash
   python3 -m http.server 8000
   ```

2. The tunnel should expose it at `https://test.bore.cum.army`

## Available ports

The bore module will automatically find unused ports on the bore.pub server. You can also specify a specific port:

```nix
test = {
  enable = true;
  localPort = 8000;
  remotePort = 8080;  # Try to use this specific remote port
  # ...
};
```

## Security

For production use, consider:

1. Using authentication secrets:
   ```nix
   test = {
     enable = true;
     localPort = 8000;
     secret = "your-secret-here";
     # ...
   };
   ```

2. Running your own bore server instead of using bore.pub

3. Adding authentication at the Caddy level:
   ```nix
   caddy.extraConfig = ''
     basicauth {
       admin $2a$14$...  # bcrypt hash
     }
   '';
   ```

## Examples in configuration.nix

The configuration file contains several commented examples:
- Web application tunnel
- API server with custom headers
- Development server using public bore.pub
- Raw TCP tunnel for databases

Uncomment and modify these examples as needed for your use case. 