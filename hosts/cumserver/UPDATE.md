# Server update fast path

Use this checklist, not the previous deployment's versions or commands blindly.
Read root/target `AGENTS.md` first: builders, service ownership and migrations differ by host.

1. **Scope once.** Inspect dirty/staged changes and record the target's current closure,
   runtime versions, failed units, containers (rootful **and rootless**), disk/RAM and
   monitoring baseline. Identify Nix, container, unmanaged and separate-release owners.
   Preserve unrelated edits, custom forks and deliberate holds; do not rebuild unknown images.
2. **Update narrowly.** Refresh relevant inputs and image digests; keep exact revisions in
   `flake.lock`, not input URLs. Compare old/new versions, then read release notes for
   changed majors, migrations and compatibility—not every unchanged dependency.
   Check plugin manifest/API requirements against the daemon **before** building.
   Check runtime/exporter compatibility, trusted proxies and container volume layouts.
3. **Evaluate, then build once.** Evaluate the target and any separately requested HM;
   run focused checks on changed code. If upstream packaging breaks, retain the working
   lock revision and record why. For source/vendor hash failures, inspect the fetched
   source/dependency change before accepting the actual hash; do not guess hashes.
   Use `nixos-rebuild <action> --flake .#<target> --build-host <builder> --target-host <target>`
   (`--no-reexec` on Darwin). Never build Linux on Darwin. Cumserver builds itself;
   offload only large uncached work per `AGENTS.md`. Check capacity before maintenance.
4. **Review dry activation before downtime.** Reuse built outputs; rerun builds/tests only
   when relevant inputs change. Record the reviewed derivation and recheck before switch:
   concurrent edits changed our closure mid-deployment. Stop and review any difference;
   do not activate unrelated changes. Use a reviewed prebuilt closure only under the
   repository's documented exceptions. HM and Starflake releases are separate operations.
5. **Database major? Separate migration, never a tag-only switch.** Obtain approval for
   downtime/data migration and separately for backups or temporary files; normal Nix
   workspaces are not permission for ad-hoc dumps. Inventory *every* cluster/client,
   locale, roles, extensions and image layout. Pause writers/backup timers; migrate into
   permanent new directories. Approved streamed transfers avoid dump files, but must
   handle bootstrap-role conflicts and pipeline failures. Compare roles/passwords,
   database properties, table contents, sequences and extensions; analyze before cutover.
   Retain originals, stop migration instances, then switch and restore writers/timers.
   Old directories are not a rollback once new writes begin; never downgrade blindly.
6. **Switch; reboot when approved.** Confirm active/boot closure, effective versions and
   running kernel afterward. Check failed system **and user** units, rootless boot startup,
   container health/networking and monitoring targets. A restart policy alone did not
   start our unmanaged rootless bot. Verify plugin status, not just daemon liveness.
   Schedule reconciliation can retry during daemon startup: check recovery before rebuilding.
7. **Prove service behavior.** Use real health/version endpoints, subscription requests,
   database/collation checks and mail TLS as applicable. Read scoped post-boot logs for
   affected and failed services; compare suspicious errors with the prior boot. Avoid
   broad secret-bearing argv/env dumps and repeated full logs. Unit-up/HTTP-200 does not
   prove browser sessions, calls, mail delivery or bot messages; state what was not tested.
8. **Close briefly.** Record deployed scope, checks, recovered startup events and concrete
   outstanding impact in follow-up beans—not a giant version/log transcript here.
   Run required repository checks (including ast-grep), inspect the staged diff, and stage
   only update-related files/hunks. Shared inputs/plugins may affect other hosts later;
   updating their definitions does not mean those hosts or separate apps were deployed.
