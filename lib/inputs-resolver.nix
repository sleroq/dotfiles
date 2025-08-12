{ lib, inputs', easyHostsHost, ... }:
let
  host = easyHostsHost;
  names = builtins.attrNames inputs';
  dashed = builtins.filter (n: builtins.match ".*-.*" n != null) names;
  baseOf = n: builtins.head (builtins.split "-" n);
  bases = lib.unique (builtins.map baseOf dashed);

  resolveFor = base:
    let hostKey = base + "-" + host; in
    if builtins.hasAttr hostKey inputs' then builtins.getAttr hostKey inputs'
    else if builtins.hasAttr base inputs' then builtins.getAttr base inputs'
    else null;

  aliasList = builtins.filter (a: a.value != null)
    (builtins.map (b: { name = b; value = resolveFor b; }) bases);
  aliasSet = lib.listToAttrs aliasList;
  resolved = inputs' // aliasSet;

  inputFor = name:
    let hostKey = name + "-" + host; in
    if builtins.hasAttr hostKey resolved then builtins.getAttr hostKey resolved
    else builtins.getAttr name resolved;
in {
  _module.args."inputsResolved'" = resolved;
  _module.args.inputFor = inputFor;
}


