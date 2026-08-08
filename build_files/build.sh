#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Client config is pulled from the server rather than committed under system_files/, so the
# repo definition has a single source of truth. The .repo file it serves carries the gpgkey
# URL, which dnf imports during the transaction below.
dnf5 -y config-manager addrepo --from-repofile=https://rpm.vries.cloud/saeverix.repo

# Wayland desktop stack. aquamarine, hyprcursor, hyprgraphics, hyprlang, hyprutils, hyprwire
# and scenefx come in as dependencies; the -devel packages are build-time only and stay out.
# fish resolves to the saeverix build while it outranks Fedora's (4.8.1 vs 4.6.0).
dnf5 install -y \
    mangowm \
    noctalia \
    fish

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
