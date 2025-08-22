let
  interplanetary = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSh54pu9bAH8DFBKPtswFJzevCft+gHZStJQ0trYGoj sleroq@cum.army";
  international = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me";
  idk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9Y+/pLBhAfjo/qKZqn7rTl4X3MBMdOuwW4sYo9pNi0 cantundo@pm.me";
  idk2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFmP6jhiag3zlSEVPemBEyXop/39WHGNnad53NH7LCtb";
  commonPublicKeys = [ interplanetary international idk idk2 ];
in
{
  "secrets/sing-box-outbounds.jsonc" = { publicKeys = commonPublicKeys; };
  "secrets/webdav-cert.pem" = { publicKeys = commonPublicKeys; };
  "secrets/webdav-key.pem" = { publicKeys = commonPublicKeys; };
  "secrets/work-vpn/ca.crt" = { publicKeys = commonPublicKeys; };
  "secrets/work-vpn/cert.crt" = { publicKeys = commonPublicKeys; };
  "secrets/work-vpn/private.key" = { publicKeys = commonPublicKeys; };
  "secrets/work-vpn/tls_auth.key" = { publicKeys = commonPublicKeys; };
}