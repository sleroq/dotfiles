# Server update fast path

Read root and target `AGENTS.md` first. Follow the user's approval, backup and
temporary-file constraints; preserve unrelated edits, custom forks and holds.

1. **Inventory once:** inspect dirty/staged scope, running versions, failed system
   and user units, rootful/rootless containers, monitoring and available disk/RAM.
   Identify Nix, image, unmanaged and separately deployed services; don't rebuild
   unknown images. Compare changed versions and check release notes for major
   migrations and compatibility, not every unchanged dependency. Check Paseo plugin
   API/manifest requirements against its daemon before building.
2. **Update and build:** refresh relevant inputs and image digests; exact revisions
   belong in `flake.lock`. Evaluate the target, run focused checks, and retain a
   working locked revision if upstream packaging is broken. Inspect source changes
   before accepting changed source/vendor hashes. Build using the target's prescribed
   builder: cumserver builds itself; offload only large uncached work if necessary.
   Use `nixos-rebuild <action> --flake .#<target> --build-host <builder> --target-host <target>`
   (`--no-reexec` on Darwin); never build Linux on Darwin.
3. **Review before downtime:** inspect the actual closure and dry activation for
   unrelated changes. Record the reviewed derivation and recheck it before switching:
   concurrent edits changed it during this update. Stop and review differences; do
   not deploy unrelated work. Reuse built outputs; repeat checks only when relevant
   inputs change. Follow repository rules for any prebuilt-closure exception.
   Standalone Home Manager and Starflake releases are separate deployments.
4. **PostgreSQL major:** get migration/downtime approval; a tag change is not a
   migration. Backups and temporary dump files require permission. Inventory both
   native and container clusters, clients, roles, extensions, locales and volume
   layouts. Pause writers and backup timers; stream to permanent new directories
   when approved, handling bootstrap roles and pipeline errors. Compare roles,
   passwords, database properties, table contents, sequences and extensions; analyze,
   stop migration instances, switch, then restore writers/timers. Retain originals;
   they cease to be a safe rollback once new writes begin.
5. **Verify deployment and approved reboot:** check active closure, versions and
   kernel, failed system/user units, containers/networking, rootless auto-start and
   monitoring targets. Check plugin status, not just daemon liveness. Exercise key
   endpoints and actual service functions (including subscriptions, database and mail
   TLS as applicable); state what wasn't tested. Review scoped post-boot logs for all
   services, including unrelated errors; compare suspicious messages with the prior
   boot and confirm startup retries recovered before treating them as failures.
6. **Close:** record real outstanding impact and follow-ups briefly. Run required
   repository checks, review the staged diff and stage only update-related files/hunks.
   Shared input changes do not mean other hosts or separate releases were deployed.
