# Bloom OS Build Modernization

**Date**: 2026-03-12
**Status**: Approved
**Scope**: Restructure `os/` directory and Containerfile to follow bootc best practices from kde-bootc, zirconium, and ublue-os/image-template.

## Problem

Bloom's OS image build has grown organically. Packages are inline in the Containerfile, config files use arbitrary names in a flat `sysconfig/` directory, services are enabled via `systemctl enable` calls scattered through the Containerfile, and there is no CI/CD for image builds. This makes the build hard to audit, slow to iterate on, and inconsistent with the bootc ecosystem's established patterns.

## Reference Repositories

| Repository | Key Patterns Adopted |
|------------|---------------------|
| [kde-bootc](https://github.com/sigulete/kde-bootc) | Declarative package lists (text files with comments), explicit package removal with reasons, `/var/log` cleanup |
| [zirconium](https://github.com/zirconium-dev/zirconium) | `scratch` context stage, fetch/post script split with `--network=none`, BuildKit cache mounts, `system_files/` mirroring real filesystem, systemd presets, os-release branding, cosign signing, OCI labels, `/opt` + `/usr/local` symlinks |
| [ublue-os/image-template](https://github.com/ublue-os/image-template) | `scratch` context stage, CI/CD pipeline (build + push + sign), disk image workflow, justfile recipes for VM testing, shellcheck linting |

## Decisions

### Adopted
- `FROM scratch AS ctx` build context pattern
- BuildKit cache mounts for dnf (`--mount=type=cache,dst=/var/cache/libdnf5`)
- tmpfs mounts for `/var`, `/tmp` during build
- Fetch/post script split with `--network=none` on post steps
- `system_files/` directory mirroring real filesystem layout
- Declarative package lists (`packages-install.txt`, `packages-remove.txt`)
- Repository setup extracted to `packages/repos.sh`
- systemd presets file instead of `systemctl enable` calls
- Cosign image signing (keypair generation, CI integration)
- Full OCI labels in Containerfile
- os-release branding (`PRETTY_NAME="Bloom OS"`)
- `/opt → /var/opt` symlink for day-2 package installs
- `rm -rf /var/*` cleanup before `bootc container lint`
- Mask upstream `bootc-fetch-apply-updates.timer`
- GitHub Actions CI/CD for image build + push + sign
- Separate manual workflow for disk image generation
- Shellcheck linting for build scripts
- `disk_config/` directory for BIB configs (iso.toml, disk.toml)

### Rejected (overcomplication for Bloom)
- Multi-arch builds (Bloom targets x86_64 mini-PCs only)
- Image rechunking (not needed at our image size/update frequency)
- ArtifactHub metadata (not a public distro)
- ISO branding with mkksiso (overkill for our install flow)
- Container `policy.json` with signature verification (premature)
- Renovate/Dependabot (can add later if needed)
- Chezmoi dotfile management (we have our own persona system)
- `/usr/local → /var/usrlocal` symlink (we install global npm packages to `/usr/local`, breaking this would require rework)

## Directory Structure

### Before

```
os/
├── Containerfile
├── bib-config.example.toml
├── bootc/
│   └── config.toml
├── scripts/                    (empty)
└── sysconfig/
    ├── bloom-bash_profile
    ├── bloom-bashrc
    ├── bloom-greeting.sh
    ├── bloom-matrix.service
    ├── bloom-matrix.toml
    ├── bloom-sudoers
    ├── bloom-sysctl.conf
    ├── bloom-tmpfiles.conf
    ├── bloom-update-check.service
    ├── bloom-update-check.sh
    ├── bloom-update-check.timer
    ├── getty-autologin.conf
    └── pi-daemon.service
```

### After

```
os/
├── Containerfile
├── build_files/
│   ├── 00-base-pre.sh            # Package removal (offline)
│   ├── 00-base-fetch.sh          # dnf install from package lists (network)
│   ├── 00-base-post.sh           # Copy system_files, presets, branding (offline)
│   ├── 01-bloom-fetch.sh         # npm install global CLI tools (network)
│   └── 01-bloom-post.sh          # Build TypeScript, configure Pi (offline)
├── system_files/
│   ├── etc/
│   │   ├── hostname
│   │   ├── issue
│   │   ├── skel/
│   │   │   ├── .bashrc
│   │   │   └── .bash_profile
│   │   ├── ssh/
│   │   │   └── sshd_config.d/
│   │   │       └── 50-bloom.conf
│   │   ├── sudoers.d/
│   │   │   └── 10-bloom
│   │   └── bloom/
│   │       └── matrix.toml
│   └── usr/
│       ├── lib/
│       │   ├── bootc/
│       │   │   └── install/
│       │   │       └── config.toml
│       │   ├── sysctl.d/
│       │   │   └── 60-bloom-console.conf
│       │   ├── systemd/
│       │   │   ├── system/
│       │   │   │   ├── bloom-matrix.service
│       │   │   │   ├── bloom-update-check.service
│       │   │   │   └── bloom-update-check.timer
│       │   │   ├── system-preset/
│       │   │   │   └── 01-bloom.preset
│       │   │   └── user/
│       │   │       └── pi-daemon.service
│       │   └── tmpfiles.d/
│       │       └── bloom.conf
│       └── local/
│           └── bin/
│               ├── bloom-greeting.sh
│               └── bloom-update-check.sh
├── packages/
│   ├── packages-install.txt       # Categorized package list with comments
│   ├── packages-remove.txt        # Packages to remove with reasons
│   └── repos.sh                   # Third-party repository setup
├── disk_config/
│   ├── disk.toml                  # BIB config for qcow2/raw
│   ├── iso.toml                   # Anaconda ISO config with bootc switch kickstart
│   └── bib-config.example.toml    # Example with user password placeholder
└── output/                        # Build artifacts (gitignored)
```

## Containerfile

```dockerfile
ARG CONTINUWUITY_IMAGE=forgejo.ellis.link/continuwuation/continuwuity:0.5.0-rc.6
ARG PI_CODING_AGENT_VERSION=0.57.1
ARG BIOME_VERSION=2.4.6
ARG TYPESCRIPT_VERSION=5.9.3
ARG CLAUDE_CODE_VERSION=2.1.73

FROM ${CONTINUWUITY_IMAGE} AS continuwuity-src

FROM scratch AS ctx
COPY os/build_files /build
COPY os/system_files /files
COPY os/packages /packages

FROM quay.io/fedora/fedora-bootc:42

# Phase 1: Remove unwanted packages (offline)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --network=none \
    /ctx/build/00-base-pre.sh

# Phase 2: Install system packages (network)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build/00-base-fetch.sh

# Phase 3: Copy system files, apply presets, branding (offline)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --network=none \
    /ctx/build/00-base-post.sh

# Phase 4: Install Node.js CLI tools + Bloom npm deps (network)
ARG PI_CODING_AGENT_VERSION
ARG BIOME_VERSION
ARG TYPESCRIPT_VERSION
ARG CLAUDE_CODE_VERSION
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    PI_CODING_AGENT_VERSION=${PI_CODING_AGENT_VERSION} \
    BIOME_VERSION=${BIOME_VERSION} \
    TYPESCRIPT_VERSION=${TYPESCRIPT_VERSION} \
    CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION} \
    /ctx/build/01-bloom-fetch.sh

# Phase 5: Build Bloom TypeScript, configure Pi (offline)
COPY . /usr/local/share/bloom/
COPY --from=continuwuity-src /sbin/conduwuit /usr/local/bin/continuwuity
RUN --mount=type=tmpfs,dst=/tmp \
    --network=none \
    /ctx/build/01-bloom-post.sh

# Optional: pre-configure WiFi for headless first-boot
ARG WIFI_SSID=""
ARG WIFI_PSK=""
RUN if [ -n "$WIFI_SSID" ]; then \
    printf '[connection]\nid=%s\ntype=wifi\nautoconnect=true\n\n[wifi]\nmode=infrastructure\nssid=%s\n\n[wifi-security]\nkey-mgmt=wpa-psk\npsk=%s\n\n[ipv4]\nmethod=auto\n\n[ipv6]\nmethod=auto\n' \
        "$WIFI_SSID" "$WIFI_SSID" "$WIFI_PSK" \
        > /etc/NetworkManager/system-connections/wifi.nmconnection && \
    chmod 600 /etc/NetworkManager/system-connections/wifi.nmconnection; \
fi

# Final cleanup + validation
RUN rm -rf /var/* && mkdir /var/tmp && bootc container lint

LABEL containers.bootc="1"
LABEL org.opencontainers.image.title="Bloom OS"
LABEL org.opencontainers.image.description="Pi-native AI companion OS on Fedora bootc"
LABEL org.opencontainers.image.source="https://github.com/pibloom/pi-bloom"
LABEL org.opencontainers.image.version="0.1.0"
```

## Build Scripts

### `00-base-pre.sh` — Package removal (offline)

```bash
#!/bin/bash
set -xeuo pipefail

# Remove packages that conflict with bootc immutability or are unnecessary
grep -vE '^\s*(#|$)' /ctx/packages/packages-remove.txt | xargs dnf -y remove || true
dnf -y autoremove
```

### `00-base-fetch.sh` — Package installation (network)

```bash
#!/bin/bash
set -xeuo pipefail

dnf -y install dnf5-plugins

# Add third-party repositories
source /ctx/packages/repos.sh

# Install all packages from the list
grep -vE '^\s*(#|$)' /ctx/packages/packages-install.txt | xargs dnf -y install --allowerasing
dnf clean all
```

### `00-base-post.sh` — System configuration (offline)

```bash
#!/bin/bash
set -xeuo pipefail

# Copy all system files to their filesystem locations
cp -avf /ctx/files/. /

# Apply systemd presets (replaces individual systemctl enable/mask calls)
systemctl preset-all --preset-mode=enable-only

# Mask upstream auto-update timer (we have our own)
systemctl mask bootc-fetch-apply-updates.timer

# Mask unused NFS services
systemctl mask rpcbind.service rpcbind.socket rpc-statd.service

# OS branding
sed -i 's|^PRETTY_NAME=.*|PRETTY_NAME="Bloom OS"|' /usr/lib/os-release

# Symlink /opt to /var/opt for day-2 package installs
rm -rf /opt && ln -s /var/opt /opt

# Remove empty NetBird state files (prevents JSON parse crash on boot)
rm -f /var/lib/netbird/active_profile.json /var/lib/netbird/default.json

# Firewall: trust NetBird tunnel interface
firewall-offline-cmd --zone=trusted --add-interface=wt0

# Set boot target
systemctl set-default multi-user.target

# Auto-login on VT1 and serial console
mkdir -p /usr/lib/systemd/system/getty@tty1.service.d \
         /usr/lib/systemd/system/serial-getty@ttyS0.service.d
```

### `01-bloom-fetch.sh` — Node.js tooling (network)

```bash
#!/bin/bash
set -xeuo pipefail

HOME=/tmp npm install -g --cache /tmp/npm-cache \
    "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    "@mariozechner/pi-coding-agent@${PI_CODING_AGENT_VERSION}" \
    "@biomejs/biome@${BIOME_VERSION}" \
    "typescript@${TYPESCRIPT_VERSION}"
rm -rf /tmp/npm-cache /var/roothome/.npm /root/.npm
```

### `01-bloom-post.sh` — Build Bloom + configure Pi (offline)

```bash
#!/bin/bash
set -xeuo pipefail

cd /usr/local/share/bloom

# Install deps and build TypeScript
HOME=/tmp npm install --cache /tmp/npm-cache
rm -rf /tmp/npm-cache /var/roothome/.npm /root/.npm
npm run build
npm prune --omit=dev

# Symlink globally-installed Pi SDK into Bloom's node_modules
ln -sf /usr/local/lib/node_modules/@mariozechner /usr/local/share/bloom/node_modules/@mariozechner

# Configure Pi settings defaults (immutable layer)
mkdir -p /usr/local/share/bloom/.pi/agent
echo '{"packages": ["/usr/local/share/bloom"]}' > /usr/local/share/bloom/.pi/agent/settings.json

# Persona directory
mkdir -p /usr/local/share/bloom/persona

# Continuwuity binary
chmod +x /usr/local/bin/continuwuity

# Appservices directory
mkdir -p /etc/bloom/appservices
```

## Package Lists

### `packages/packages-install.txt`

```
# System essentials
sudo
openssl
curl
wget
unzip
jq

# Development tools
git
git-lfs
ripgrep
fd-find
bat
htop
just
ShellCheck
tmux

# Runtime
nodejs
npm
libatomic

# Container tooling
podman
buildah
skopeo
oras

# VM testing
qemu-system-x86
edk2-ovmf

# Network & remote access
openssh-server
openssh-clients
firewalld

# Desktop (for remote access via code-server/Cinny)
chromium

# VS Code (repo added by repos.sh)
code

# Mesh networking (repo added by repos.sh)
netbird
```

### `packages/packages-remove.txt`

```
# Conflicts with bootc immutability — tries to install packages on immutable OS
PackageKit-command-not-found

# Unnecessary — journalctl provides better logging for servers
rsyslog

# Unnecessary — bootc provides rollback, no rescue initramfs needed
dracut-config-rescue

# Deprecated — firewalld uses nftables directly
iptables-services
iptables-utils
```

### `packages/repos.sh`

```bash
#!/bin/bash
# Third-party repository setup — sourced by 00-base-fetch.sh

# VS Code (Microsoft)
rpm --import https://packages.microsoft.com/keys/microsoft.asc
printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
    > /etc/yum.repos.d/vscode.repo

# NetBird mesh networking
printf '[netbird]\nname=netbird\nbaseurl=https://pkgs.netbird.io/yum/\nenabled=1\ngpgcheck=0\nrepo_gpgcheck=1\ngpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key\n' \
    > /etc/yum.repos.d/netbird.repo
```

## System Files

### `system_files/usr/lib/systemd/system-preset/01-bloom.preset`

```
# Bloom OS service presets
enable sshd.service
enable netbird.service
enable bloom-matrix.service
enable bloom-update-check.timer
```

All other system files are the same content as current `os/sysconfig/` files, just moved to their filesystem-mirrored locations. The getty autologin drop-in files go to `system_files/usr/lib/systemd/system/getty@tty1.service.d/autologin.conf` and `system_files/usr/lib/systemd/system/serial-getty@ttyS0.service.d/autologin.conf`.

## Disk Config

### `disk_config/iso.toml`

```toml
[customizations.installer.kickstart]
contents = """
%post
bootc switch --mutate-in-place --transport registry ghcr.io/pibloom/bloom-os:latest
%end
"""

[customizations.installer.modules]
enable = [
  "org.fedoraproject.Anaconda.Modules.Storage",
  "org.fedoraproject.Anaconda.Modules.Runtime",
  "org.fedoraproject.Anaconda.Modules.Users"
]
disable = [
  "org.fedoraproject.Anaconda.Modules.Subscription"
]
```

### `disk_config/disk.toml`

```toml
[install.filesystem.root]
type = "btrfs"

[[customizations.filesystem]]
mountpoint = "/"
minsize = "40 GiB"
```

## CI/CD

### `.github/workflows/build-os.yml`

Triggers on push to main (when `os/`, `Containerfile`, `package.json`, or source changes), weekly schedule, and manual dispatch. Steps:

1. Checkout
2. `podman build -f os/Containerfile -t bloom-os:latest .`
3. Login to GHCR
4. Push to `ghcr.io/pibloom/bloom-os:latest`
5. Cosign sign with `SIGNING_SECRET`

### `.github/workflows/build-disk.yml`

Manual dispatch only. Builds ISO or qcow2 via bootc-image-builder, uploads as artifact.

## Justfile Changes

- Update `build` recipe to use new Containerfile location (unchanged — it already points to `os/Containerfile`)
- Update BIB config paths: `bib_config` → `os/disk_config/disk.toml` for qcow2, `os/disk_config/iso.toml` for ISO
- Add `lint-os` recipe: `shellcheck os/build_files/*.sh os/packages/repos.sh`
- Update `iso` and `qcow2` recipes to use `disk_config/` paths

## Cosign Setup

One-time setup (documented in README, not automated):
1. `COSIGN_PASSWORD="" cosign generate-key-pair`
2. Commit `cosign.pub` to repo root
3. Add `cosign.key` content as `SIGNING_SECRET` GitHub secret
4. Add `cosign.key` to `.gitignore`

## Migration Notes

- All content from `os/sysconfig/` moves to `os/system_files/` at the correct filesystem path
- `os/bootc/config.toml` moves to `os/system_files/usr/lib/bootc/install/config.toml`
- `os/bib-config.example.toml` moves to `os/disk_config/bib-config.example.toml`
- `os/scripts/` (empty) is removed, replaced by `os/build_files/`
- The `build-iso.sh` script at repo root is removed (justfile covers this)
- No functional changes to boot behavior — same services, same config, same user experience
