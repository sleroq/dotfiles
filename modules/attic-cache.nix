{ ... }:

{
  nix.settings = {
    extra-substituters = [
      "https://cache.cum.army/music-link"
      "https://cache.cum.army/reactor"
      "https://cache.cum.army/bayan"
      "https://cache.cum.army/celine"
      "https://cache.cum.army/sieve"
      "https://cache.cum.army/fumo-gateway"
      "https://cache.cum.army/kopoka"
      "https://cache.cum.army/zefxi"
    ];
    extra-trusted-public-keys = [
      "music-link:agcaBqYuR+kFl8V9OS2P8nekfhTXYfg4i8bA/0+/yII="
      "reactor:6zTPyqXJya+MKMFxKL/KvobYqjD2Bh/tvPS9FM+pNlo="
      "bayan:YQMea+eOeAtGHW3Zljllru7AIKm7GSoPo2rDA0bGBR4="
      "celine:1WjkFvIY1yy80g1tET0fOGmUe17QBR/NbP0Y9QpTRto="
      "sieve:UrgY6krg1isOiCkmz9Um9gyvyDaaMPRlyh0F+O4ov+U="
      "fumo-gateway:XQHLMyDoYCcsiVIdoAGf/B1HANxxTKR2wNr1SHL3WXw="
      "kopoka:AhAzvs/u600OVl/wMujSPopaGhn840LGu1xPuBZJD9U="
      "zefxi:F5fF+u3Zx4sagOUOZrjU7pHNebA1k8demQVtLRNGDsM="
    ];
  };
}
