# Traffic on `div`

## Public: Cloudflare Tunnel

`sleroq.cloudflared` owns locally managed tunnels and their credentials. The host
defines each tunnel once; a public service adds a route:

```nix
sleroq.cloudflared.tunnels.<tunnel-name>.routes."app.cum.army" =
  "http://127.0.0.1:<port>";
```

Cloudflared units and tokens do not belong in service modules. DNS is routed after
deployment with `cloudflared tunnel route dns <uuid> <hostname>`.

## Private: Tailscale

Cumserver reaches private endpoints (such as metrics) at
`div.capybara-menkent.ts.net:<port>`. Their ports are allowed only on
`networking.firewall.interfaces.tailscale0.allowedTCPPorts`.
