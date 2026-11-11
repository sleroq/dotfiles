{
  buildGo127Module,
  bash,
  git,
}:

buildGo127Module {
  pname = "agent-jobs";
  version = "0.1.0";
  src = ./.;
  vendorHash = null;
  nativeCheckInputs = [
    bash
    git
  ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
  ];
}
