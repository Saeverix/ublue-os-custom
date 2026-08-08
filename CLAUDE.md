# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A fork of [ublue-os/image-template](https://github.com/ublue-os/image-template): a template for building a custom [bootc](https://github.com/bootc-dev/bootc) OCI image derived from a Universal Blue base image (currently `ghcr.io/ublue-os/bazzite:stable`, digest-pinned in the `Containerfile`). There is no application code — the "product" is a container image that users `bootc switch` to and boot as their OS.

The repo is still largely at template defaults (see "Template state" below).

## Commands

All local work goes through `just` (recipes are in `Justfile`, which loads variables from `image-template.env` via `set dotenv-filename`). `just` with no arguments lists recipes.

```bash
just build [target_image] [tag]     # podman build the image (defaults: $IMAGE_NAME:$DEFAULT_TAG)
just check                          # verify Justfile / *.just formatting — CI runs this and fails the build
just fix                            # apply just --fmt
just lint                           # shellcheck all *.sh
just format                         # shfmt --write all *.sh
just clean                          # remove _build*, output/, generated manifests

sudo just build && sudo just ostree-rechunk   # build as root so you can rebase without podman image scp
sudo bootc switch --transport containers-storage localhost/<image>:latest

just build-qcow2 / build-raw / build-iso      # disk images via bootc-image-builder into output/
just rebuild-qcow2 ...                        # rebuild the container image first, then the disk image
just run-vm-qcow2 ...                         # boot the disk image in qemux/qemu, serves a browser console
just spawn-vm [rebuild] [type] [ram]          # boot via systemd-vmspawn instead
```

There are no unit tests. Verification is: `bootc container lint` (last `RUN` in the `Containerfile`), `just check`/`just lint`, and actually booting a VM.

Requires `just`, `podman`, `jq`; `shellcheck`/`shfmt` for the lint recipes. Disk-image and rechunk recipes need root and are heavy.

## How a build fits together

1. **`Containerfile`** — a `scratch` stage named `ctx` holds `build_files/` and `system_files/` so they are available during the build without being baked into the final image. The real stage is `FROM <base image>`, then a single `RUN --mount=type=bind,from=ctx,...` that executes `/ctx/build.sh`, then `bootc container lint`.
2. **`build_files/build.sh`** — the only customization entrypoint. It `cp -avf /ctx/system_files/. /` and then installs packages (`dnf5 install`) and enables units (`systemctl enable`). Runs with `set -ouex pipefail`, so any failure fails the image build.
3. **`system_files/`** — files laid down verbatim onto the image root; mirror the target path (`system_files/etc/...` → `/etc/...`, `system_files/usr/...` → `/usr/...`). The `.gitkeep` files exist because git can't track empty dirs.
4. **`image-template.env`** — single source of truth for `IMAGE_NAME`, `REPO_ORGANIZATION`, `IMAGE_DESC`, `IMAGE_KEYWORDS`, `IMAGE_LOGO_URL`, `DEFAULT_TAG`, `BIB_IMAGE`. The `Justfile` re-exports these; ArtifactHub / OCI labels in `just build` are derived from them.

Notably, the base image is **only** in the `Containerfile`, while the *output* image identity is **only** in `image-template.env` — changing what you build on and changing what you publish are separate edits.

### Rechunking

`just ostree-rechunk` (rpm-ostree, requires root, used by CI) and `just rechunk` (chunkah, newer alternative) both re-split the image's layers for better download resumability. They rewrite the local tag in place, so run them after `just build` and before pushing.

## CI

- **`.github/workflows/build.yml`** — PRs, pushes to `main`, and a daily 10:05 UTC cron. Calls the same `just` recipes as local dev (`check` → `build` → `ostree-rechunk` → `generate-build-tags` → `tag-images`), then pushes to `ghcr.io/<owner>/<image>` and cosign-signs the digest. Login/push/sign steps are all gated on `github.event_name != 'pull_request' && github.ref == default_branch`, so PRs build but never publish. Signing needs a `SIGNING_SECRET` repo secret (the `cosign.key`; `.gitignore` keeps it out of git). Tags come from `generate-build-tags`: date- and SHA-suffixed variants, and SHA-bearing tags are emitted **only when the git tree is clean**.
- **`.github/workflows/build-disk.yml`** — manual `workflow_dispatch` (choose `amd64`/`arm64`, optional S3 upload) plus PRs touching the disk configs. Matrix over `qcow2` and `anaconda-iso`. Its `IMAGE_NAME`/`IMAGE_REGISTRY`/`DEFAULT_TAG` env block is a **separate hardcoded copy** of what `image-template.env` holds — keep the two in sync when renaming the image.
- Action versions are SHA-pinned and updated by Renovate (`.github/renovate.json5`) / Dependabot.

## Template state

Things still carrying upstream template values — check before assuming they're intentional:

- `image-template.env`: `IMAGE_NAME=image-template`, `REPO_ORGANIZATION="alice-and-bob"`.
- `artifacthub-repo.yml`: placeholder `repositoryID` / owner.
- `disk_config/iso-gnome.toml` and `iso-kde.toml` both still `bootc switch` to `ghcr.io/ublue-os/image-template:latest`.
- **Broken reference:** `Justfile` (`build-iso`, `rebuild-iso`, `run-vm-iso`) and `build-disk.yml` both point at `disk_config/iso.toml`, which does not exist — only the `iso-gnome`/`iso-kde` variants do. ISO recipes will fail until one is chosen, copied to `iso.toml`, or the paths are updated.
- `build_files/build.sh` installs `tmux` and enables `podman.socket` as examples, with commented COPR usage.
- `README.md` is upstream's user-facing template documentation, not documentation of this fork.
