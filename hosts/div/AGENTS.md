# Div traffic

- Public routes belong to `sleroq.cloudflared.tunnels.<name>.routes."<hostname>" =
  "http://127.0.0.1:<port>"`. Define tunnels/credentials once on the host, not in
  service modules. After deployment: `cloudflared tunnel route dns <uuid> <hostname>`.
- Cumserver accesses private endpoints at `div.capybara-menkent.ts.net:<port>`.
  Open their ports only in `networking.firewall.interfaces.tailscale0.allowedTCPPorts`.
