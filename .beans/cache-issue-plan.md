# Fix: Add cache.nixos.org to Darwin Configuration

## Problem
Darwin host building from source because:
- Only `cache.flakehub.com` is configured (via Determinate Nix)
- `nixpkgs-portable` locked to recent revision `eb8d947de7b0` (Feb 1, 2026)
- Revision not available in cache.flakehub.com, causing source builds

## Solution: Add cache.nixos.org

### Option 1: Create Darwin Shared Module (Recommended)

**Step 1:** Create `/Users/sleroq/develop/dotfiles/hosts/shared-darwin.nix`
```nix
{ ... }:
{
  nix.settings = {
    substituters = [
      "https://cache.nixos.org/"
      "https://cache.flakehub.com"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
}
```

**Step 2:** Add to flake.nix portable host modules (around line 208)
```nix
modules = [
  inputs.determinate.darwinModules.default
  inputs.agenix.darwinModules.default
  inputs.home-manager-portable.darwinModules.home-manager
  ./hosts/shared-darwin.nix  # Add this line
  # ... rest of modules
]
```

**Step 3:** Apply changes
```bash
nh darwin switch --hostname portable
```

### Option 2: Inline Module (Quicker but less clean)

Add inline module to flake.nix portable host:
```nix
modules = [
  # ... other modules
  (
    { ... }:
    {
      nix.settings.substituters = [ "https://cache.nixos.org/" ];
      nix.settings.trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    }
  )
]
```

## Verification

Check what will be downloaded vs built:
```bash
nh darwin switch --hostname portable -- --dry-run
```

Look for "will download" instead of "will build" for packages.

## Optional: Also Change nixpkgs URL

For better long-term cache behavior, also consider changing in flake.nix:30:
```nix
nixpkgs-portable.url = "github:nixos/nixpkgs/nixos-unstable";
```

This avoids channel URLs which can lock to very recent revisions.

## Files to Modify
- `flake.nix:208-238` - Add shared-darwin.nix module to portable host
- `hosts/shared-darwin.nix` - Create new file (Option 1)
