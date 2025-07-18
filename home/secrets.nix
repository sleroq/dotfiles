let
  interplanetary = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSh54pu9bAH8DFBKPtswFJzevCft+gHZStJQ0trYGoj sleroq@cum.army";
  international = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK72BBTnP5Os5ZQfS1BuigNzWMqNFl7lgUH4CJq1bl9P cantundo@pm.me";
  idk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9Y+/pLBhAfjo/qKZqn7rTl4X3MBMdOuwW4sYo9pNi0 cantundo@pm.me";
  commonPublicKeys = [ interplanetary international idk ];
in
{
  "secrets/flameshot-auth-token" = { publicKeys = commonPublicKeys; };
} 