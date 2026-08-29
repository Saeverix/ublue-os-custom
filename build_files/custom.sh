#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Client config is pulled from the server rather than committed under system_files/, so the
# repo definition has a single source of truth. The .repo file it serves carries the gpgkey
# URL, which dnf imports during the transaction below.
dnf5 -y config-manager addrepo --from-repofile=https://rpm.vries.cloud/saeverix.repo

dnf5 install -y \
    mangowm \
    noctalia \
    fish
