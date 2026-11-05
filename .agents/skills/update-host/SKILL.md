---
name: update-host
description: Update a host in this repository, including its inputs, packages, and containers. Use when asked to update or upgrade a host.
---

# Update a host

1. Read the repository and target host deployment instructions. Update all inputs, packages, and container images used by the host to their latest appropriate versions. Keep changes scoped to the host; note when an input is shared with other hosts.
2. Research and list all major and breaking changes, migration requirements, and expected impact. Ask the user for confirmation before deployment; flag anything that could not be verified.
3. Do not create backups as part of the update.
4. After confirmation, deploy following the host's instructions and verify its services, effective versions, and user-facing functionality. Fix problems if possible; otherwise report them to the user.
