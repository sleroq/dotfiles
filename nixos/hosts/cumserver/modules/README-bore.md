# Bore Tunneling Module

This module provides a wrapper around [bore-cli](https://github.com/ekzhang/bore) to create TCP tunnels that expose local ports to the internet, with automatic Caddy reverse proxy integration.

## Features

- Multiple tunnel configurations
- Automatic systemd service creation for each tunnel
- Caddy reverse proxy integration with custom domains
- Support for authentication secrets
- Configurable local and remote hosts/ports

## Configuration

### Basic Usage

```nix
cumserver.bore.enable = true;
cumserver.bore.tunnels = {
  webapp = {
    enable = true;
    localPort = 3000;
    caddy.enable = true;
    caddy.domain = "webapp.bore.cum.army";
  };
};
```

### Advanced Configuration

```nix
cumserver.bore.tunnels = {
  api = {
    enable = true;
    localPort = 8080;
    localHost = "localhost";
    server = "bore.pub";  # or your own bore server
    remotePort = 8080;    # specific remote port (optional)
    secret = "my-secret"; # authentication secret (optional)
    
    caddy.enable = true;
    caddy.domain = "api.bore.cum.army";
    caddy.extraConfig = ''
      encode zstd gzip
      header X-Frame-Options DENY
      header X-Content-Type-Options nosniff
    '';
  };
};
```

## Options

### Per-tunnel options:

- `enable`: Enable this tunnel
- `localPort`: Local port to expose (required)
- `localHost`: Local host to expose (default: "localhost")
- `server`: Remote bore server address (default: "bore.pub")
- `remotePort`: Specific remote port to use (optional)
- `secret`: Authentication secret (optional)

### Caddy integration:

- `caddy.enable`: Enable Caddy reverse proxy for this tunnel
- `caddy.domain`: Domain name for the virtual host (default: "{name}.bore.cum.army")
- `caddy.extraConfig`: Additional Caddy configuration

## How it works

1. Each enabled tunnel creates a systemd service that runs `bore local {localPort} --to {server}`
2. If Caddy integration is enabled, a virtual host is created that reverse proxies to the local port
3. The bore client connects to the remote server and exposes the local port
4. Traffic flows: Internet → Caddy → Local Service

## Example Use Cases

### Development Server
```nix
dev-server = {
  enable = true;
  localPort = 4000;
  caddy.enable = true;
  caddy.domain = "dev.bore.cum.army";
};
```

### API with Authentication
```nix
secure-api = {
  enable = true;
  localPort = 8080;
  secret = "my-api-secret";
  caddy.enable = true;
  caddy.domain = "api.bore.cum.army";
  caddy.extraConfig = ''
    basicauth {
      admin $2a$14$...  # bcrypt hash
    }
  '';
};
```

### Database Tunnel (no Caddy)
```nix
postgres = {
  enable = true;
  localPort = 5432;
  server = "my-bore-server.com";
  secret = "db-tunnel-secret";
  # No Caddy integration for raw TCP
};
```

## Security Considerations

- Use authentication secrets when possible
- Consider running your own bore server for sensitive applications
- Use HTTPS/TLS termination at Caddy level
- Implement proper authentication in your applications
- Monitor tunnel usage and logs

## Troubleshooting

Check tunnel status:
```bash
systemctl status bore-{tunnel-name}
```

View tunnel logs:
```bash
journalctl -u bore-{tunnel-name} -f
```

Test local service:
```bash
curl localhost:{localPort}
```

Test through Caddy:
```bash
curl https://{domain}
``` 