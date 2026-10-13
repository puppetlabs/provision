# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`puppetlabs-provision` is a Puppet module (published as `puppetlabs-provision` on the Forge) that ships Bolt **tasks** and **plans** for provisioning and tearing down test systems — Docker containers, Vagrant VMs, LXD containers, internal ABS pooler machines, and cloud VMs via the Provision Service. It is primarily consumed by [puppet_litmus](https://puppetlabs.github.io/content-and-tooling-team/docs/litmus/) for acceptance testing, but tasks can also be run directly with Bolt or plain Ruby.

The module's core job for every provisioner is the same: spin up (or destroy) a system, configure SSH/WinRM access on it, and add/remove a corresponding target entry in a Bolt `inventory.yaml` file.

## Commands

Development tooling is Ruby/PDK based. Always run through `bundle exec`.

```sh
bundle install                                    # install gems
bundle exec rake spec                             # run all rspec unit/task tests
bundle exec rspec spec/unit/inventory_helper_spec.rb   # run a single spec file
bundle exec rspec spec/tasks/docker_spec.rb -e "provision"  # run specs matching a description
bundle exec rake validate                         # puppet syntax + lint + metadata lint
bundle exec rake lint                             # puppet-lint only
bundle exec rubocop                               # Ruby style (tasks/, lib/, spec/)
bundle exec rubocop -A                            # auto-correct Ruby style
```

CI (`.github/workflows/ci.yml`) runs the shared `puppetlabs/cat-github-actions` module CI on Ruby 3.1 and additionally runs **shellcheck** against the `.sh` tasks.

### Running a task directly (development/debugging)

Tasks read JSON parameters from stdin. This is the fastest way to iterate on a task without Bolt:

```sh
echo '{ "platform": "ubuntu:14.04", "action": "provision", "inventory": "/path/to/module/" }' | bundle exec ruby tasks/docker.rb
```

### Running via Bolt

```sh
bundle exec bolt task run provision::docker --targets localhost action=provision platform=ubuntu:14.04
bundle exec bolt task run provision::docker --targets localhost action=tear_down node_name=localhost:2222
```

`tear_down` requires `node_name`; `provision` requires `platform`. The two are mutually exclusive (enforced at the top of each task).

## Architecture

### Tasks (`tasks/`)

Each provisioner is a `<name>.json` (Puppet task metadata: parameter types, description, bundled `files`) paired with an implementation (`<name>.rb` for Ruby provisioners, `<name>.sh` for shell). The Ruby provisioners (`abs`, `docker`, `lxd`, `vagrant`, `provision_service`) all follow the same contract:

1. Parse JSON params from `$stdin` — typically `action`, `platform`, `node_name`, `inventory`, `vars`.
2. Branch on `action` (`provision` vs `tear_down`).
3. On success print a JSON result `{ status: 'ok', node_name: ... }`; on `StandardError` print `{ _error: { kind: ..., msg: ..., backtrace: ... } }` and `exit 1`. This `_error` envelope is the Bolt task error convention — preserve it.

The `.json` `files` array lists which `lib/` helpers Bolt bundles with the task; **if a task starts requiring a new helper, add it there** or it won't be shipped to the executor.

Shell tasks (`install_pe.sh`, `install_puppetserver.sh`, `fix_secure_path.sh`) run *on* the provisioned target rather than locally.

### Shared helpers (`lib/`)

These are plain Ruby (not Puppet functions) `require_relative`'d by the tasks:

- **`inventory_helper.rb`** — `InventoryHelper` (a `SimpleDelegator` over the inventory Hash). The single source of truth for reading/mutating `inventory.yaml`. Use `InventoryHelper.open(location)` (memoized per-location), then `.add(node, group)`, `.lookup(...)`, `.remove(node)`, and `.save`. It resolves a directory argument to `<dir>/inventory.yaml` (with a deprecated fallback to `spec/fixtures/litmus_inventory.yaml` for old puppet_litmus). Provisioned Linux/SSH targets go in the `ssh_nodes` group; Windows/WinRM targets in `winrm_nodes`.
- **`task_helper.rb`** — cross-cutting utilities: `run_local_command` (Open3 wrapper that raises on non-zero exit), `platform_is_windows?` / `platform_uses_ssh` (regex-based platform classification — note the documented edge cases in the comments), `on_windows?`, and `token_from_fogfile` (reads the ABS token from `~/.fog`).
- **`docker_helper.rb`** — Docker-specific exec/inspect/teardown helpers used by `docker.rb`.

### Plans (`plans/*.pp`)

Puppet-language Bolt plans that orchestrate the tasks into higher-level workflows (e.g. `provisioner.pp` provisions a PE server plus agents, `tests_against_agents.pp` iterates inventory targets and runs `provision::run_tests` against each). Plans call tasks via `run_task('provision::<task>', ...)` and operate on inventory groups/roles set through the `vars` parameter (e.g. `vars='role: agent_linux'`).

### Hiera data (`data/`, `hiera.yaml`)

Module-level Hiera (v5) keyed by OS family/release, used by the `.sh` install tasks and plans to look up OS-specific values. `data/common.yaml` holds defaults.

## Conventions & gotchas

- **Puppet 8 only** (`>= 8.0.0 < 9.0.0`). Ruby files use `# frozen_string_literal: true`.
- All Ruby files are linted by RuboCop with the puppetlabs config in `.rubocop.yml`; puppet-lint relative-classname and 140-char checks are disabled (see `Rakefile`).
- The `vars` task parameter is a **YAML string**, parsed with `YAML.safe_load`, and merged into the inventory target's `vars`. Special keys are interpreted by provisioners (e.g. `docker_run_opts`, `role`, `vagrant_box_url`).
- Many behaviors are configurable via environment variables as an alternative to task params (e.g. `DOCKER_HOST`, `VAGRANT_BOX_URL`, `VAGRANT_PASSWORD`, `LITMUS_ENABLE_SYNCED_FOLDER`, `LITMUS_HYPERV_VSWITCH`). Check both when changing provisioner behavior.
- Generated reference docs live in `REFERENCE.md` (puppet-strings); `CHANGELOG.md` is generated by `github_changelog_generator`. Don't hand-edit either for routine changes.
- `.fixtures.yml` symlinks this module and pulls `facts`, `puppet_conf`, and `puppet_agent` for spec runs.

## Hard Constraints

- Read the files relevant to a task before suggesting or making a change.
- Never merge a PR.
- Never work directly on `main` / `master`.
- Never push without explicit instruction.
- Never delete a file without permission — even after a blanket "yes to all".
- Never output, log, save, or hardcode security-sensitive values: passwords, tokens, API keys, private keys, secrets, credentials. Don't write them to files, commit messages, or responses.
