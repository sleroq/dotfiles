# ClientHello fragmentation

`remnawave-clienthello-final-mask.json` is a reviewed input for the panel's
**Host → Final Mask** field, not a Nix option or an automatically deployed setting.
The live panel remains the source of truth for hosts and profiles.

## Live configuration

Applied on 2026-10-27: `finalMask` is set to the JSON file's contents on these
existing hosts only:

- `🇵🇱 Warsaw (recommended)` — public TCP 443, Chrome fingerprint.
- `🇵🇱 Warsaw (fallback configuration)` — public TCP 443, Safari fingerprint.

Both previously had `finalMask: null`. All other host fields, server profiles,
credentials, ports, and routes are unchanged, including non-443 entries and the
disabled Frankfurt entry. The mask is not on server inbounds: the goal is to
fragment the client's outgoing ClientHello.

## Compatibility and verification

- The deployed Remnawave backend 3.4.7 emits this mask in VLESS links as `fm` and
  in Xray JSON as `streamSettings.finalmask`.
- Clients must support both the delivered setting and Xray FinalMask. Remnawave's
  VLESS Mihomo/Clash/Stash/Sing-box outputs do not carry this TCP mask. This is
  not fixable for every current core by translating subscription fields alone;
  see the implementation checks below.
- The supplied paste uses `interval`, which Xray 26.7.28 ignores here. Use `delay`
  for the intended 10–20 ms spacing; fragment lengths are 10–20 bytes.
- Small fragments and deliberate delays can noticeably increase handshake time.
  Fragmentation is a mitigation, not a guarantee against an operator's filtering.

## REALITY client support checked on 2026-10-27

| Client core | Outer REALITY ClientHello fragmentation |
| --- | --- |
| Xray 26.7.28 | The existing `streamSettings.finalmask` setting is supported. |
| Sing-box 1.14.4 | `tls.fragment` and `tls.record_fragment` exist, but the REALITY handshake bypasses the wrapper that implements them. Emitting them does not enable fragmentation on this path. |
| Mihomo 1.19.33 | No supported native ClientHello-fragmentation option was found in the VLESS/REALITY configuration and handshake implementation. |

Sing-box's ordinary uTLS client applies `tf.NewConn` in
[`UTLSClientConfig.Client`](https://github.com/SagerNet/sing-box/blob/c005f35300ce76427dc285481ec5695f5b179cd2/common/tls/utls_client.go#L85-L94).
Its [REALITY handshake](https://github.com/SagerNet/sing-box/blob/c005f35300ce76427dc285481ec5695f5b179cd2/common/tls/reality_client.go#L130-L150)
instead passes the original connection directly to `utls.UClient`. Do not
confuse fragmenting application TLS inside the tunnel with fragmenting this
outer proxy handshake. `fragment_fallback_delay` also is not a translation of
Xray's random fragment-length and delay ranges.

Mihomo's [TLS configuration and REALITY branch](https://github.com/MetaCubeX/mihomo/blob/3f27ef39f8c96bbfbc8b0b9bb10f5c9ef60149d8/transport/vmess/tls.go)
provide no equivalent option. Adding an unrecognized `tls-fragment` YAML field
is not a fix, even if a parser accepts it. The inspected FlClashX main branch
uses [upstream Mihomo](https://github.com/pluralplay/FlClashX/blob/main/core/go.mod);
this does not identify the core installed on a particular phone.

Supporting this behavior in all three clients requires client-core changes,
not just a Remnawave template or generator patch. Do not introduce custom
cores, mobile-app builds, or a local fragmentation sidecar without approval.
Before claiming support, verify actual outer ClientHello fragmentation on the
wire with the intended client build; a configuration check or successful
HTTPS request alone does not prove it.

## Verification and rollback

The panel API patches contained only `uuid` and `finalMask`. Read-back comparison
confirmed exactly two host changes; the other five hosts and all profiles were
unchanged. All three nodes remained connected; no service restarts were needed.

A real public subscription returned HTTP 200, with the mask on exactly the two
TCP-443 entries. Both generated Xray JSON configurations passed Xray 26.7.28's
configuration test and real HTTPS probes from cumserver: HTTP 204 from gstatic
and HTTP 200 with a 65,536-byte download from Cloudflare for each host.
This does not establish bypass on an affected subscriber's operator network.
Clients must refresh subscriptions and use a compatible application/core.

Pre-change host objects, rollback payloads, and a PostgreSQL SQL dump are stored
root-only on cumserver under:

```text
/var/lib/remnawave/backup/clienthello-fragmentation-20261027T091258Z/
```

Rollback is restoring the saved `finalMask` values through the panel API, then
refreshing clients.

Reference: [Xray 26.7.28 fragment settings](https://github.com/XTLS/Xray-core/blob/5ca6f4b7d4dc20a881d4330e498892697627ec0c/infra/conf/transport_finalmask.go#L253-L320).

# REALITY minimum-client compatibility

Applied through the panel API on 2026-10-27 at 12:15 UTC with user approval:
all five REALITY inbounds explicitly use `minClientVer: "1.8.1"`.

- `div-private` / `DIV_VLESS_REALITY` (Sofia): added the omitted minimum.
- `Remnawave Cumserver` / `VLESS_REALITY_CUMSERVER` (Frankfurt): added the
  omitted minimum; the public Frankfurt VLESS host remains disabled.
- `Remnawave Warsaw`: its three REALITY inbounds already specified `1.8.1`
  and were not patched.

Xray 26.7.28 defaults an omitted minimum to `26.3.27`, rejecting Mihomo's
older advertised REALITY version. The explicit lower minimum admits those
clients; this deliberately relaxes the newer default client-version policy.
See the [pinned version-gate implementation](https://github.com/XTLS/Xray-core/blob/5ca6f4b7d4dc20a881d4330e498892697627ec0c/infra/conf/transport_security.go#L100-L126).

Exact profile read-back confirmed only those two `minClientVer` additions.
Running Xray configuration dumps confirmed both changed nodes received them,
all three nodes remained connected, and the entire host inventory was unchanged.
Hysteria2 settings, credentials, routes, and host enablement were untouched.

Using the unchanged public subscription and Mihomo 1.19.33, Sofia failed all
three HTTPS checks and a download before the change with REALITY authentication
errors. Afterward it passed three HTTP 204 checks and an HTTP 200 download of
exactly 131,072 bytes, with no REALITY authentication failures. Warsaw recommended
and both direct Hysteria2 entries passed the same post-change checks. These spot
checks confirm the compatibility correction, not sustained mobile-network health
or resolution of the separate FRP/direct-route failures.

Root-only pre-change profiles, API rollback payloads, and a PostgreSQL dump:

```text
/var/lib/remnawave/backup/reality-minclientver-20261027T121557Z/
```

To roll back, PATCH the two changed profiles through `/api/config-profiles` using
their original `config` objects from `rollback.json`; leave Warsaw unchanged.
Do not restore an entire profile over subsequent edits without comparing it first.
