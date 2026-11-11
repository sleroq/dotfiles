{ buildGo127Module, git }:

buildGo127Module {
  pname = "agent-jobs";
  version = "0.1.0";
  src = ./.;
  vendorHash = null;
  nativeCheckInputs = [ git ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
  ];
}
