# Cloud environment: `infra`

Claude Code cloud sessions for `rainforest-homelab` and `rainforest-iot` share one
environment, `infra`, configured at claude.ai/code. The UI keeps no history of it, so both
repositories carry this same directory as its versioned copy. Change it in both, then paste.

The environment checks Terraform syntax and wiring. It cannot plan or apply: the Docker
hosts, k3s clusters and Cloudflare account are reachable only from the home network, and no
credential belongs in a cloud VM.

## Environment settings

**Name** `infra`

**Network access** Custom, with "Also include default list of common package managers"
checked, plus:

```text
releases.hashicorp.com
registry.terraform.io
github.com
objects.githubusercontent.com
release-assets.githubusercontent.com
```

`releases.hashicorp.com` serves the Terraform binary and the `hashicorp/*` providers.
`registry.terraform.io` resolves provider versions. The kreuzwerker/docker,
gavinbunney/kubectl and cloudflare/cloudflare providers download from GitHub releases.

**Environment variables** none.

**Setup script** the contents of [`setup-script.sh`](./setup-script.sh). It installs
Terraform 1.5.7, the version on the Mac, so `fmt` agrees between the two. Each step's exit
code goes to `/var/log/cloud-setup.log`.

## What a session can check

```bash
git submodule update --init --depth 1
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
```

Neither root module declares a backend, and `validate` does not configure providers, so all
three run without credentials. In `rainforest-homelab`, `validate` hashes
`modules/comfyui/server/requirements.txt`, which lives in the ComfyUI submodule, so the
submodule has to be checked out first. `plan` and `apply` need the home network and stay local.

A session with both repositories runs neither repository's SessionStart hook, so ask for
these checks in the prompt.

## Verification

| Date | Repo | Session | `fmt -check` | `validate` |
| ---- | ---- | ------- | ------------ | ---------- |
