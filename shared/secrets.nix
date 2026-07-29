let
  interplanetary = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSh54pu9bAH8DFBKPtswFJzevCft+gHZStJQ0trYGoj sleroq@cum.army";
  interplanetaryStateKey = "age1whlw5p3mmw6vkxh69sx6y6h3j88xj98d908zn2uvyvphfja9n9jqg20g52";
  idk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9Y+/pLBhAfjo/qKZqn7rTl4X3MBMdOuwW4sYo9pNi0 cantundo@pm.me";
  idk2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFmP6jhiag3zlSEVPemBEyXop/39WHGNnad53NH7LCtb";
  div = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKqaD8lUj2IoSXbd+ZngR3w+7rKxS7DU/3CPo4jd9SE9 root@shared";
  commonPublicKeys = [ interplanetary interplanetaryStateKey idk idk2 ];
in
{
  "secrets/sing-box-outbounds.jsonc" = { publicKeys = commonPublicKeys; };
  "secrets/webdav-cert.pem" = { publicKeys = commonPublicKeys; };
  "secrets/webdav-key.pem" = { publicKeys = commonPublicKeys; };
  "secrets/work-vpn/ca.crt" = { publicKeys = commonPublicKeys; };
  "secrets/work-vpn/cert.crt" = { publicKeys = commonPublicKeys; };
  "secrets/work-vpn/private.key" = { publicKeys = commonPublicKeys; };
  "secrets/work-vpn/tls_auth.key" = { publicKeys = commonPublicKeys; };
  "secrets/cloudflared.key" = { publicKeys = commonPublicKeys ++ [ div ]; };
}
