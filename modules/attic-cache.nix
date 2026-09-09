{ ... }:

{
  nix.settings = {
    extra-substituters = [
      "https://cache.cum.army/music-link"
      "https://cache.cum.army/reactor"
      "https://cache.cum.army/bayan"
    ];
    extra-trusted-public-keys = [
      "music-link:agcaBqYuR+kFl8V9OS2P8nekfhTXYfg4i8bA/0+/yII="
      "reactor:6zTPyqXJya+MKMFxKL/KvobYqjD2Bh/tvPS9FM+pNlo="
      "bayan:YQMea+eOeAtGHW3Zljllru7AIKm7GSoPo2rDA0bGBR4="
    ];
  };
}
