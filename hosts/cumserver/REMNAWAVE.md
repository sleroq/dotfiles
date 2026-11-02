# Remnawave client compatibility

The live panel is the source of truth for hosts and profiles. The settings below
were applied through its API, not automatically deployed by Nix.

## ClientHello fragmentation

`remnawave-clienthello-final-mask.json` is the reviewed input for **Host → Final
Mask** on the existing Warsaw recommended (Chrome) and fallback (Safari) TCP-443
hosts only. It fragments the client's outgoing ClientHello, not server inbounds.
Other hosts, profiles, credentials, ports, and routes were unchanged.

Remnawave 3.4.7 emits this mask as `fm` in VLESS links and
`streamSettings.finalmask` in Xray JSON. Compatibility is core-specific:

| Client core checked | Outer REALITY ClientHello fragmentation |
| --- | --- |
| Xray 26.7.28 | Supports `streamSettings.finalmask`. |
| Sing-box 1.14.4 | REALITY bypasses the wrapper implementing `tls.fragment` and `tls.record_fragment`. |
| Mihomo 1.19.33 | No supported equivalent in its VLESS/REALITY implementation. |

Remnawave's VLESS Mihomo/Clash/Stash/Sing-box outputs do not carry this TCP mask.
Template changes alone cannot supply missing core support. An accepted YAML
field, inner application-TLS fragmentation, or a successful HTTPS request does
not prove outer ClientHello fragmentation. FlClashX's upstream core dependency
does not identify the build installed on a phone.

Use `delay` for the intended 10–20 ms spacing: Xray 26.7.28 ignores the supplied
paste's `interval` here. Fragment lengths are 10–20 bytes. Small fragments and
delays increase handshake time; fragmentation does not guarantee filtering
bypass. See the [pinned Xray settings](https://github.com/XTLS/Xray-core/blob/5ca6f4b7d4dc20a881d4330e498892697627ec0c/infra/conf/transport_finalmask.go#L253-L320).

Clients must refresh subscriptions and use a compatible core. Verify the outer
ClientHello on the wire before claiming support. Custom cores, mobile builds,
or a fragmentation sidecar require approval.

## REALITY minimum client version

All five REALITY inbounds explicitly use `minClientVer: "1.8.1"`: Sofia's
`DIV_VLESS_REALITY`, Frankfurt's `VLESS_REALITY_CUMSERVER`, and Warsaw's three
inbounds. Frankfurt's public VLESS host remains disabled.

Xray 26.7.28 defaults an omitted minimum to `26.3.27`, rejecting Mihomo's older
advertised REALITY version. The explicit minimum deliberately relaxes that
policy; see the [version gate](https://github.com/XTLS/Xray-core/blob/5ca6f4b7d4dc20a881d4330e498892697627ec0c/infra/conf/transport_security.go#L100-L126).

The explicit minimum addresses client compatibility, not separate FRP/direct-route
failures or sustained mobile-network health.

## Rollback

Root-only pre-change objects, API rollback payloads, and PostgreSQL dumps remain
on cumserver:

- `/var/lib/remnawave/backup/clienthello-fragmentation-20261027T091258Z/`
- `/var/lib/remnawave/backup/reality-minclientver-20261027T121557Z/`

Restore saved `finalMask` values through the panel API, then refresh clients.
For the minimum-version change, PATCH only the two changed profiles through
`/api/config-profiles` using the original `config` objects in `rollback.json`;
leave Warsaw unchanged. Compare against subsequent edits before restoring a
whole profile.
