# Nazar Clean Reinstall Runbook: NixOS + microvm.nix

This runbook is the operator-facing plan for wiping the Hetzner `nazar` server and rebuilding it from scratch as a NixOS bare-metal host that runs the service guests as declarative `microvm.nix` MicroVMs.

It is written so the operator can open Pi on a laptop, point it at this repository, and have Pi assist through the installation step by step.

> **Destructive warning:** this runbook includes disk-wipe steps. Do not execute the install command until every pre-wipe gate is checked and the operator gives live confirmation.

---

## 1. Desired end state

```text
Hetzner bare metal server: nazar
└─ NixOS host
   ├─ declarative users, SSH, sudo, firewall, NetBird, monitoring, backups
   ├─ systemd-networkd public networking matched by NIC MAC
   ├─ microvm.nix host module
   ├─ routed TAP MicroVM network, preserving the 10.10.10.0/24 service plan
   ├─ MicroVMs: git, minecraft, ownloom, ownloom-data
   ├─ explicit persistent state under /persist or the chosen state root
   └─ git-backed infrastructure repo as source of truth
```

The install method should be:

1. prepare and validate a NixOS flake on the laptop;
2. boot the Hetzner server into Rescue;
3. install via `nixos-anywhere` + `disko` over SSH;
4. first boot into NixOS;
5. verify NetBird/private admin access;
6. restore/start MicroVMs;
7. validate services and backups.

---

## 2. Non-negotiable operating rules

The clean NixOS host must preserve the current security model.

### 2.1 Users

- `alex` is the daily human/admin user.
- `alex` has passwordless sudo.
- `root` is break-glass/admin fallback only.
- `root` and `alex` SSH keys come from `nix/users/admin-keys.nix`.
- Linux passwords remain locked in normal boot.
- No shared passwords, setup keys, private keys, or password hashes are committed to git.

Target NixOS policy shape:

```nix
users.mutableUsers = false;

users.users.root = {
  openssh.authorizedKeys.keys = adminKeys;
  hashedPassword = "!";
};

users.users.alex = {
  isNormalUser = true;
  extraGroups = [ "wheel" ];
  openssh.authorizedKeys.keys = adminKeys;
  hashedPassword = "!";
};

security.sudo.wheelNeedsPassword = false;
```

### 2.2 SSH

- SSH authentication is key-only.
- Password and keyboard-interactive auth are disabled.
- Root SSH is key-only, not password login.
- Public TCP/22 is closed in steady state.
- Temporary public SSH during first boot is allowed only as an explicit migration exception and must be removed immediately after NetBird is verified.

Target NixOS policy shape:

```nix
services.openssh = {
  enable = true;
  authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d/%u" ];
  settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "prohibit-password";
  };
};
```

### 2.3 NetBird

- NetBird is the primary private access plane.
- Canonical admin access after migration is OpenSSH over NetBird to `alex@nazar`.
- NetBird embedded SSH is not the canonical shell path.
- NetBird setup material is provided out-of-band, not in git.
- Decide before cutover whether to restore the old NetBird peer identity or enroll as a new peer.

Target NixOS policy shape:

```nix
services.netbird = {
  enable = true;
  clients.default.config = {
    ServerSSHAllowed = false;
    EnableSSHRoot = false;
  };
};
```

### 2.4 Public exposure

Default posture stays private.

Allowed steady-state public exposure should be only what is intentionally approved:

- NetBird/WireGuard UDP as required by the NetBird client;
- Minecraft public TCP/25565 and UDP/24454 if the operator chooses to keep public Minecraft;
- public landing page only if explicitly retained;
- no public SSH;
- no public admin dashboard;
- OwnLoom and OwnLoom Data stay NetBird/private only;
- Forgejo stays NetBird/private only unless a later decision changes that.

---

## 3. Current server facts to verify again in Rescue

Current facts from the running Proxmox host before reinstall:

| Item | Current value |
|---|---|
| Provider | Hetzner Server Auction / Robot |
| Hostname | `nazar` |
| Public IPv4 | `167.235.12.22` |
| IPv4 gateway | `167.235.12.1` |
| Public IPv6 | `2a01:4f8:262:1b01::2/64` |
| IPv6 gateway | `fe80::1` |
| Main NIC | `enp0s31f6` |
| Main NIC MAC | `90:1b:0e:9e:eb:f6` |
| Boot mode currently observed | legacy BIOS, not UEFI |
| Current disks | 2x Samsung NVMe 476.9 GiB |
| Current disk 1 by-id | `/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ-00B00_S675NX0T505998` |
| Current disk 2 by-id | `/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ-00B00_S675NX0T505978` |
| Current layout | mdadm RAID1 + ext4 root, ext3 boot, swap |
| Current host NetBird | `nazar.netbird.cloud` / `100.124.39.100` |
| Current private service subnet | `10.10.10.0/24`, gateway `10.10.10.1` |

Do **not** blindly trust this table during the install. Re-run the verification commands in Rescue because NIC names, disk enumeration, and Rescue boot environment can differ.

---

## 4. Recommended installation approach

Use **`nixos-anywhere` + `disko` from the laptop**.

Why this is the recommended path:

- `nixos-anywhere` installs NixOS over SSH from an arbitrary Linux/rescue system.
- It supports flakes directly.
- It integrates with `disko` for reproducible partitioning/formatting/mounting.
- It can generate hardware configuration during installation.
- It avoids manual snowflake install steps on the server.

Important behavior:

- `disko` is destructive in the install flow. It will destroy filesystems on the disks it manages.
- `nixos-anywhere` default phases are `kexec,disko,install,reboot`.
- After install, SSH host keys change; remove old `known_hosts` entries.
- Hetzner Rescue is one-boot only: activating Rescue in Robot does not reboot the server; you must reboot/reset after activation.

Primary references:

- nixos-anywhere quickstart/reference: <https://nix-community.github.io/nixos-anywhere/>
- disko quickstart/reference: <https://github.com/nix-community/disko>
- Hetzner Rescue: <https://docs.hetzner.com/robot/dedicated-server/troubleshooting/hetzner-rescue-system/>
- Hetzner systemd-networkd networking: <https://docs.hetzner.com/robot/dedicated-server/network/network-configuration-using-systemd-networkd/>
- microvm.nix docs: <https://microvm-nix.github.io/microvm.nix/>

---

## 5. Laptop working model with Pi

Recommended laptop directory layout:

```text
~/src/nazar-stack/
├── nazar/
├── forgejo/
├── minecraft/
├── ownloom/
└── ownloom-data/
```

Run Pi from the laptop in `~/src/nazar-stack/nazar`:

```bash
cd ~/src/nazar-stack/nazar
pi
```

Suggested Pi prompt at the start of the install session:

```text
We are following runbooks/NIXOS_MICROVM_CLEAN_REINSTALL.md to reinstall the Hetzner server nazar from Rescue into NixOS + microvm.nix. Act as the install copilot. Before every destructive command, restate the exact target disks, target host, and rollback point. Do not ask me to paste secrets into git or chat. Help me verify command output and update the runbook if reality differs.
```

Use three terminals:

1. **Terminal A:** Pi in the local repo.
2. **Terminal B:** SSH into Hetzner Rescue.
3. **Terminal C:** local `nixos-anywhere` command from the laptop.

Keep secrets in a password manager or local files outside the repo. Do not paste NetBird setup keys, private keys, htpasswd contents, or age private keys into Pi unless you deliberately accept that exposure.

---

## 6. Bootstrap-source problem: Forgejo will be offline

The current `nazar` flake inputs point at Forgejo hosted on the `git` VM:

```text
forgejo        git+ssh://git@git.nazar.studio:10022/nazar/forgejo.git
minecraft      git+ssh://git@git.nazar.studio:10022/nazar/minecraft.git
ownloom        git+ssh://git@git.nazar.studio:10022/nazar/ownloom.git
ownloom-data   git+ssh://git@git.nazar.studio:10022/nazar/ownloom-data.git
```

During Rescue and clean reinstall, that Forgejo VM will be down. Therefore the first NixOS host install must not depend on fetching those inputs from `git.nazar.studio`.

Use one of these bootstrap strategies.

### Preferred strategy: local sibling clones and temporary lock overrides

From the laptop:

```bash
cd ~/src/nazar-stack/nazar

# Save the production lock before changing anything locally.
cp flake.lock flake.lock.before-local-bootstrap

# Lock service inputs to local sibling clones for the bootstrap build.
nix flake lock \
  --override-input forgejo path:../forgejo \
  --override-input minecraft path:../minecraft \
  --override-input ownloom path:../ownloom \
  --override-input ownloom-data path:../ownloom-data

# Verify the local bootstrap lock evaluates.
nix flake metadata
nix flake check --no-build
```

Rules:

- Do not commit this temporary bootstrap `flake.lock` unless that is an intentional design choice.
- After the new Git service is restored, switch the lock back to Forgejo remotes and commit the production lock.
- If Pi edits files during the bootstrap, inspect `git diff` before proceeding.

### Alternative strategy: separate minimal installer flake

Create a small local installer flake that contains only:

- `nixpkgs`;
- `disko`;
- `microvm.nix` if needed for host packages;
- `nixosConfigurations.nazar` host config;
- no Forgejo-hosted service inputs.

This reduces bootstrap dependency risk but creates a second source of truth. Prefer this only if the main flake cannot be made bootstrap-safe.

---

## 7. Pre-install implementation requirements

Before entering Hetzner Rescue, the repo must contain an actual NixOS host configuration. This runbook alone is not enough.

Required flake output:

```text
nixosConfigurations.nazar
```

Expected implementation files:

```text
nix/hosts/nazar/default.nix
nix/hosts/nazar/disko.nix
nix/hosts/nazar/hardware-configuration.nix        # generated or placeholder-imported
nix/modules/host/users.nix
nix/modules/host/ssh.nix
nix/modules/host/networking.nix
nix/modules/host/firewall.nix
nix/modules/host/netbird.nix
nix/modules/host/microvm-host.nix
nix/modules/host/backup.nix
nix/modules/host/monitoring.nix
```

Expected later MicroVM outputs or in-host declarations:

```text
git
minecraft
ownloom
ownloom-data
```

Do not run `nixos-anywhere` until these pass locally:

```bash
cd ~/src/nazar-stack/nazar
nix fmt
nix flake check --no-build
nix build .#nixosConfigurations.nazar.config.system.build.toplevel
```

If `nixosConfigurations.nazar` is not implemented yet, stop and implement it first.

---

## 8. Recommended NixOS host design

### 8.1 Storage recommendation

Recommended first production cutover storage: **legacy BIOS GRUB + mdadm RAID1 + ext4**.

Reasoning:

- current server already boots in legacy BIOS;
- current disks are under 2 TiB;
- mdadm/ext4 is conservative and easy to recover from Hetzner Rescue;
- ZFS is attractive for snapshots, but adds kernel/module and operational complexity during the first NixOS cutover.

ZFS can be a later migration once NixOS+microVM is stable.

Recommended high-level layout:

```text
both NVMe disks
├─ BIOS boot partition for GRUB
└─ mdadm member partition
   └─ mdadm RAID1
      ├─ swap, optional
      └─ ext4 root filesystem /
         ├─ /nix
         ├─ /persist
         └─ /var/lib/microvms or symlink/bind to /persist/microvms
```

Persistent state root:

```text
/persist
├── microvms/
│   ├── git/
│   ├── minecraft/
│   ├── ownloom/
│   └── ownloom-data/
├── backups/
├── secrets/
└── repos/
```

Implementation notes:

- Use stable `/dev/disk/by-id/...` device paths in `disko.nix`.
- Install GRUB to both disks.
- Keep the disko config explicit and reviewed; it is the disk wipe source of truth.
- Test with `nixos-anywhere --vm-test` where possible, but remember VM tests do not prove Hetzner boot mode.

### 8.2 Boot mode

Current host is BIOS (`/sys/firmware/efi` absent). The initial NixOS host should use GRUB for BIOS boot unless Rescue/KVM verification shows the server is now booting UEFI.

Target NixOS shape:

```nix
boot.loader.grub = {
  enable = true;
  devices = [
    "/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ-00B00_S675NX0T505998"
    "/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ-00B00_S675NX0T505978"
  ];
};
```

If UEFI is deliberately enabled later, replace this with a tested ESP/systemd-boot or GRUB-EFI design.

### 8.3 Public network

Use `systemd-networkd` matched by NIC MAC, not only interface name.

Hetzner dedicated-server guidance says the main IPv4 should be configured as `/32` with the gateway as a peer/on-link route. IPv6 uses `fe80::1` as gateway.

Target NixOS shape:

```nix
networking.useDHCP = false;
networking.useNetworkd = true;
systemd.network.enable = true;

systemd.network.networks."10-uplink" = {
  matchConfig.MACAddress = "90:1b:0e:9e:eb:f6";
  addresses = [
    {
      Address = "167.235.12.22/32";
      Peer = "167.235.12.1/32";
    }
    { Address = "2a01:4f8:262:1b01::2/64"; }
  ];
  routes = [
    { Gateway = "167.235.12.1"; }
    { Gateway = "fe80::1"; }
  ];
  linkConfig.RequiredForOnline = "routable";
};
```

Verify exact syntax against the implemented NixOS module before installing.

### 8.4 Host firewall

Steady-state intent:

```text
public IPv4/IPv6:
  deny TCP/22
  allow only intentional public service ports
  allow NetBird/WireGuard behavior required by the client

NetBird interface wt0:
  allow OpenSSH TCP/22 to host
  allow private web/dashboard ports if implemented
  allow private service ingress to host reverse proxy/forwarding

MicroVM TAP interfaces:
  allow routed guest traffic and explicit forwards
```

If temporary public SSH is used for first boot, it must be a named migration flag in the Nix config, ideally source-limited to the operator's current public IP.

Suggested first-boot decision:

| Mode | Pros | Cons |
|---|---|---|
| Strict NetBird only | Matches final policy immediately | If NetBird enrollment fails, use Rescue to repair |
| Temporary public SSH from operator IP | Safer first-boot troubleshooting | Requires an explicit cleanup rebuild |

Recommended for remote bare metal: use a temporary, source-limited public SSH exception **only if** the operator wants reduced lockout risk. Otherwise rely on Rescue.

### 8.5 NetBird bootstrap

Prepare NetBird enrollment outside git.

Preferred local secret staging layout on laptop:

```text
~/nazar-install-extra-files/
└── var/lib/nazar/bootstrap/
    └── netbird-setup-key
```

Pass it to `nixos-anywhere` with `--extra-files ~/nazar-install-extra-files`.

The NixOS host config should have a one-shot service that:

1. waits for network and `netbird.service`;
2. checks whether NetBird is already connected/enrolled;
3. if not enrolled, runs `netbird up --setup-key <key>`;
4. shreds/removes the setup key after successful enrollment;
5. does not loop forever or leak the key into logs.

Do not commit the setup key. Revoke one-time setup keys after use.

Decision gate:

```text
[ ] Restore old NetBird peer state to keep 100.124.39.100
[ ] Or enroll a new peer and update NetBird DNS/policies/custom records
```

Clean enrollment is simpler. Restoring old peer identity is useful only if keeping `100.124.39.100` is important.

---

## 9. MicroVM design

### 9.1 microvm.nix host mode

The host imports:

```nix
microvm.nixosModules.host
```

`microvm.nix` host mode provides:

- `/var/lib/microvms` state directories;
- `microvm@<name>.service` systemd units;
- TAP setup units;
- virtiofsd units;
- declarative MicroVM build/deploy options.

Use fully declarative MicroVM configs for the first cutover where practical. This keeps the host flake as the source of truth.

### 9.2 Guest inventory

Preserve the existing service IP plan conceptually:

| Guest | Old VMID | MicroVM tap | Guest IP | Suggested MAC | Service |
|---|---:|---|---|---|---|
| `git` | 101 | `vm101` | `10.10.10.21` | `02:00:00:00:00:21` | Forgejo |
| `minecraft` | 110 | `vm110` | `10.10.10.30` | `02:00:00:00:00:30` | PaperMC |
| `ownloom` | 120 | `vm120` | `10.10.10.40` | `02:00:00:00:00:40` | OwnLoom app/wiki/Pi |
| `ownloom-data` | 121 | `vm121` | `10.10.10.41` | `02:00:00:00:00:41` | DAV/Radicale |

Host/gateway address remains conceptually `10.10.10.1`, but with routed TAP each guest may use host routes (`/32`) rather than a shared L2 bridge.

### 9.3 Routed TAP networking

Prefer routed TAP over a bridge.

Why:

- no shared L2 segment;
- less ARP/NDP/MAC spoofing risk;
- cleaner fit for one-public-IP rented dedicated servers;
- host owns NAT and public forwarding declaratively.

Host-side sketch:

```nix
systemd.network.networks."30-vm101" = {
  matchConfig.Name = "vm101";
  addresses = [ { Address = "10.10.10.1/32"; } ];
  routes = [ { Destination = "10.10.10.21/32"; } ];
  networkConfig.IPv4Forwarding = true;
  linkConfig.RequiredForOnline = "no";
};
```

Guest-side sketch:

```nix
microvm.interfaces = [ {
  id = "vm101";
  type = "tap";
  mac = "02:00:00:00:00:21";
} ];

systemd.network.networks."10-eth" = {
  matchConfig.MACAddress = "02:00:00:00:00:21";
  addresses = [ { Address = "10.10.10.21/32"; } ];
  routes = [
    { Destination = "10.10.10.1/32"; GatewayOnLink = true; }
    {
      Destination = "0.0.0.0/0";
      Gateway = "10.10.10.1";
      GatewayOnLink = true;
    }
  ];
  networkConfig.DNS = [ "10.10.10.1" "1.1.1.1" "9.9.9.9" ];
};
```

NAT sketch:

```nix
networking.nat = {
  enable = true;
  externalInterface = "enp0s31f6"; # or matched/actual uplink name
  internalIPs = [ "10.10.10.0/24" ];
};
```

For public Minecraft, add explicit port forwards in the chosen firewall/NAT implementation:

```text
167.235.12.22:25565/tcp -> 10.10.10.30:25565/tcp
167.235.12.22:24454/udp -> 10.10.10.30:24454/udp
```

### 9.4 Persistent state

Recommended host paths:

| Guest | Host path | Guest mount | Notes |
|---|---|---|---|
| `git` | `/persist/microvms/git/forgejo` | `/var/lib/forgejo` | Forgejo DB/repos/state if preserving app state |
| `minecraft` | `/persist/microvms/minecraft/state` | `/var/lib/minecraft` | world, plugins, configs |
| `ownloom` | `/persist/microvms/ownloom/ownloom` | `/var/lib/ownloom` | wiki/app state as implemented |
| `ownloom` | `/persist/microvms/ownloom/ownloom-web` | `/var/lib/ownloom-web` | audit/web state |
| `ownloom-data` | `/persist/microvms/ownloom-data/data` | `/var/lib/ownloom-data` | WebDAV root and secrets |
| `ownloom-data` | `/persist/microvms/ownloom-data/radicale` | `/var/lib/radicale/collections` | calendar/contact state |

For each guest, also share the host `/nix/store` read-only as recommended by microvm.nix to avoid huge guest images:

```nix
microvm.shares = [
  {
    source = "/nix/store";
    mountPoint = "/nix/.ro-store";
    tag = "ro-store";
    proto = "virtiofs";
  }
];
```

Exact state mounts must be tested per hypervisor. Start with `qemu` if virtiofs compatibility is more important than minimalism; start with `cloud-hypervisor` only after confirming required shares/devices work for these guests.

### 9.5 Autostart order

Start services in dependency order:

1. `git`
2. `ownloom-data`
3. `ownloom`
4. `minecraft`

The host can set `microvm.autostart`, but dependency ordering may require systemd overrides or service dependencies if one guest needs another at boot.

---

## 10. Secrets and external files

Secrets remain outside git.

Minimum secret inventory:

```text
NetBird setup key or old NetBird client state
SOPS age private key, if SOPS is enabled before/at cutover
Forgejo secrets/app.ini material if preserving full Forgejo state
Forgejo SSH host/app keys if preserving Git SSH identity
service deploy keys
ownloom-data htpasswd file
ownloom-data wiki backup SSH key and known_hosts
ownloom personal WebDAV password file
any break-glass console password hash, if enabled
```

Suggested laptop staging root:

```text
~/nazar-install-extra-files/
└── var/lib/nazar/bootstrap/
    ├── netbird-setup-key
    ├── age-key.txt                         # only if used by config
    └── README.local-secrets                # local only; do not copy to git
```

Pass with:

```bash
--extra-files ~/nazar-install-extra-files
```

After first boot, verify the host either consumed/shredded bootstrap secrets or moved them into the intended protected path with mode `0600`/`0700`.

---

## 11. Pre-wipe backup confirmation

The user states that required backups have been made. Still, before wiping, verify the backup set is readable from the laptop.

### 11.1 Repository bundles

From the laptop or current host before Rescue:

```bash
mkdir -p "$HOME/nazar-backup/git-bundles"
for repo in "$HOME/src/nazar-stack/nazar" "$HOME/src/nazar-stack/forgejo" "$HOME/src/nazar-stack/minecraft" "$HOME/src/nazar-stack/ownloom" "$HOME/src/nazar-stack/ownloom-data"; do
  name=$(basename "$repo")
  git -C "$repo" status --short --branch
  git -C "$repo" bundle create "$HOME/nazar-backup/git-bundles/$name.bundle" --all
  git -C "$repo" bundle verify "$HOME/nazar-backup/git-bundles/$name.bundle"
  git -C "$repo" rev-parse HEAD > "$HOME/nazar-backup/git-bundles/$name.HEAD"
done
```

### 11.2 Service state decision matrix

Mark each row before wiping:

| Service | Preserve state? | Backup verified? | Restore target |
|---|---|---|---|
| Forgejo app DB/settings/repos | yes / no | yes / no | `/persist/microvms/git/forgejo` |
| Minecraft world/server state | yes / no | yes / no | `/persist/microvms/minecraft/state` |
| OwnLoom wiki/app/web state | yes / no | yes / no | `/persist/microvms/ownloom/...` |
| OwnLoom Data DAV/Radicale | yes / no | yes / no | `/persist/microvms/ownloom-data/...` |
| Secrets | yes | yes / no | `/persist/secrets` or service paths |

If a row says `preserve state = yes` and `backup verified = no`, stop.

### 11.3 Final pre-wipe gate

Do not proceed until this is all true:

```text
[ ] I have the five Git repos locally: nazar, forgejo, minecraft, ownloom, ownloom-data.
[ ] I have off-host backups of every mutable service state I intend to preserve.
[ ] I have NetBird enrollment material or restored state outside git.
[ ] I have all needed service secrets outside git.
[ ] I have Hetzner Robot access.
[ ] I can boot Rescue and SSH to it.
[ ] The NixOS host flake output .#nazar evaluates locally.
[ ] The disko config has the correct two disk by-id paths.
[ ] The networking config has the correct NIC MAC, IPs, and gateways.
[ ] The rollback path is acceptable.
[ ] I explicitly accept wiping both NVMe disks.
```

---

## 12. Local validation before Rescue

From laptop:

```bash
cd ~/src/nazar-stack/nazar

git status --short --branch
git diff --stat

# If using local bootstrap lock overrides, confirm them now.
nix flake metadata
nix flake check --no-build
nix build .#nixosConfigurations.nazar.config.system.build.toplevel
```

If the host config imports `nix/hosts/nazar/hardware-configuration.nix`, create a placeholder committed/importable file before running `nixos-anywhere --generate-hardware-config`, or use a generated facter path per the nixos-anywhere docs.

Optional VM test:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nazar \
  --vm-test
```

This tests the NixOS/disko configuration in a VM. It does not prove Hetzner BIOS boot, NIC MAC, or actual disk paths.

---

## 13. Hetzner Rescue procedure

### 13.1 Activate Rescue

In Hetzner Robot:

1. open `Servers`;
2. select `nazar` / `167.235.12.22`;
3. open `Rescue` tab;
4. select Linux Rescue, 64-bit;
5. add/select your SSH public key if available;
6. activate Rescue;
7. reboot/reset the server.

Important Rescue facts:

- Rescue activation is valid for one boot.
- Activation alone does not reboot the server.
- If you wait too long, Rescue activation expires.
- Rescue runs from RAM and does not touch disks until you do.
- SSH as `root` on port `22` or `222`.

### 13.2 Connect to Rescue

From laptop:

```bash
export NAZAR_IP=167.235.12.22
ssh-keygen -R "$NAZAR_IP" || true
ssh -o StrictHostKeyChecking=accept-new root@$NAZAR_IP
# If port 22 fails:
ssh -p 222 -o StrictHostKeyChecking=accept-new root@$NAZAR_IP
```

### 13.3 Verify Rescue facts

In Rescue:

```bash
hostnamectl || true
uname -a
ip -br link
ip -br addr
ip -4 route
ip -6 route
lsblk -e7 -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
ls -l /dev/disk/by-id/ | grep -E 'nvme|ata|wwn' | sort
cat /proc/mdstat || true
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
```

Expected based on current state:

```text
main NIC MAC: 90:1b:0e:9e:eb:f6
IPv4:         167.235.12.22
IPv4 gateway: 167.235.12.1
IPv6:         2a01:4f8:262:1b01::2/64
IPv6 gateway: fe80::1
boot mode:    BIOS
2x NVMe:      S675NX0T505998 and S675NX0T505978
```

If any expected fact differs, stop and update the NixOS config before installing.

---

## 14. The destructive install command

Run from the laptop, not from Rescue.

### 14.1 Key-auth Rescue

```bash
cd ~/src/nazar-stack/nazar
export NAZAR_IP=167.235.12.22

nix run github:nix-community/nixos-anywhere -- \
  --print-build-logs \
  --generate-hardware-config nixos-generate-config ./nix/hosts/nazar/hardware-configuration.nix \
  --extra-files "$HOME/nazar-install-extra-files" \
  --flake .#nazar \
  --target-host root@$NAZAR_IP \
  -i ~/.ssh/id_ed25519
```

Adjust `~/.ssh/id_ed25519` to the actual SSH key selected in Robot/Rescue.

### 14.2 Password-auth Rescue

If Rescue only provides a password:

```bash
cd ~/src/nazar-stack/nazar
export NAZAR_IP=167.235.12.22
read -rsp 'Rescue root password: ' SSHPASS; export SSHPASS; echo

nix run github:nix-community/nixos-anywhere -- \
  --env-password \
  --print-build-logs \
  --generate-hardware-config nixos-generate-config ./nix/hosts/nazar/hardware-configuration.nix \
  --extra-files "$HOME/nazar-install-extra-files" \
  --flake .#nazar \
  --target-host root@$NAZAR_IP

unset SSHPASS
```

### 14.3 If not passing extra files

If NetBird/secrets bootstrap is fully manual or handled another way, omit:

```text
--extra-files "$HOME/nazar-install-extra-files"
```

But be aware that strict no-public-SSH first boot requires NetBird to enroll successfully or you will need Rescue again.

### 14.4 What success looks like

`nixos-anywhere` should finish with no error and reboot the server. It may take several minutes.

After it finishes, SSH host keys will have changed:

```bash
ssh-keygen -R 167.235.12.22
ssh-keygen -R nazar.netbird.cloud || true
```

---

## 15. First boot validation

### 15.1 Wait for reboot

From laptop:

```bash
ping -c 3 167.235.12.22 || true
```

If public ping is blocked or flaky, do not assume failure. Check Robot console/status or wait for NetBird.

### 15.2 Verify NetBird access

If preserving old NetBird peer identity:

```bash
ping -c 3 100.124.39.100
ssh alex@100.124.39.100
```

If clean-enrolled as a new peer:

1. check NetBird admin UI for the new `nazar` peer;
2. note the new `100.x.y.z` IP;
3. update local variable:

```bash
export NAZAR_NB_IP=100.x.y.z
ssh alex@$NAZAR_NB_IP
```

Inside the new host:

```bash
whoami
hostname
sudo -n true
systemctl --failed --no-pager
netbird status
ip -br addr
ip route
ss -ltnup
```

Expected:

- user is `alex`;
- `sudo -n true` succeeds without password;
- NetBird is connected;
- no unexpected failed systemd units;
- public uplink has expected IPv4/IPv6;
- `wt0` exists with NetBird IP.

### 15.3 Verify public SSH posture

From laptop/public network:

```bash
nc -vz 167.235.12.22 22
```

Expected steady-state result: refused/filtered.

If a temporary public SSH migration exception was used, immediately remove it:

```bash
ssh alex@$NAZAR_NB_IP
cd /srv/nazar  # or wherever the repo is checked out on the host
sudo nixos-rebuild switch --flake .#nazar
```

Then repeat the `nc` check.

### 15.4 If first boot is unreachable

Do not guess. Use this order:

1. Check Hetzner Robot server status.
2. Try NetBird admin UI: did the peer appear?
3. If temporary public SSH was enabled, try public SSH as `alex` or `root` with key.
4. If unreachable, activate Rescue again and inspect the installed system.

Rescue inspection sketch:

```bash
ssh root@167.235.12.22
lsblk -f
# Mount according to actual disko layout, for example:
mount /dev/disk/by-label/nixos /mnt
journalctl --directory=/mnt/var/log/journal -b -1 --no-pager | tail -200 || true
```

Exact mount commands depend on the final disko layout.

---

## 16. Restore source repos on the new host

The new host should have a local clone of the infra repo, for example:

```text
/srv/nazar
```

Possible restore from laptop:

```bash
rsync -a --delete ~/src/nazar-stack/nazar/ alex@$NAZAR_NB_IP:/srv/nazar/
ssh alex@$NAZAR_NB_IP 'sudo chown -R alex:users /srv/nazar && git -C /srv/nazar status --short --branch'
```

If `/srv/nazar` is root-owned by policy, use a root-owned deployment path and a separate writable checkout for editing. Decide this in the host config.

Also restore sibling service repos if the host build path uses local overrides or if host-side recovery clones are desired:

```bash
rsync -a --delete ~/src/nazar-stack/forgejo/ alex@$NAZAR_NB_IP:/srv/forgejo/
rsync -a --delete ~/src/nazar-stack/minecraft/ alex@$NAZAR_NB_IP:/srv/minecraft/
rsync -a --delete ~/src/nazar-stack/ownloom/ alex@$NAZAR_NB_IP:/srv/ownloom/
rsync -a --delete ~/src/nazar-stack/ownloom-data/ alex@$NAZAR_NB_IP:/srv/ownloom-data/
```

Do not restore secrets with broad `rsync` unless file ownership and permissions are explicitly correct.

---

## 17. Restore service state

Restore only the state the operator intentionally preserved.

General pattern:

1. stop the relevant MicroVM if already running;
2. restore files into `/persist/microvms/<name>/...`;
3. fix ownership/modes;
4. start the MicroVM;
5. validate service health.

Example skeleton:

```bash
ssh alex@$NAZAR_NB_IP
sudo systemctl stop microvm@minecraft.service || true
sudo mkdir -p /persist/microvms/minecraft/state
# restore archive here; exact command depends on backup format
sudo chown -R 1000:100 /persist/microvms/minecraft/state  # example only; verify guest UID/GID
sudo systemctl start microvm@minecraft.service
```

Do not use example UID/GID values blindly. Verify guest service users and ownership.

---

## 18. Start and validate MicroVMs

Start in dependency order.

```bash
ssh alex@$NAZAR_NB_IP

sudo systemctl start microvm@git.service
sudo systemctl status microvm@git.service --no-pager

sudo systemctl start microvm@ownloom-data.service
sudo systemctl status microvm@ownloom-data.service --no-pager

sudo systemctl start microvm@ownloom.service
sudo systemctl status microvm@ownloom.service --no-pager

sudo systemctl start microvm@minecraft.service
sudo systemctl status microvm@minecraft.service --no-pager
```

If autostart is enabled, use status instead:

```bash
systemctl status 'microvm@*.service' --no-pager
```

### 18.1 Basic guest SSH checks

From host:

```bash
ssh alex@10.10.10.21 'hostname; systemctl --failed --no-pager'
ssh alex@10.10.10.30 'hostname; systemctl --failed --no-pager'
ssh alex@10.10.10.40 'hostname; systemctl --failed --no-pager'
ssh alex@10.10.10.41 'hostname; systemctl --failed --no-pager'
```

Expected:

- SSH works from host to each guest;
- `alex` exists;
- no failed units except known/triaged ones.

### 18.2 Forgejo validation

```bash
ssh alex@10.10.10.21 'systemctl is-active forgejo; ss -ltn | grep -E ":3000|:10022"'
curl --noproxy '*' -I http://10.10.10.21:3000/
```

After private DNS/reverse proxy is restored:

```bash
curl -I http://git.nazar.studio/
git ls-remote ssh://git@git.nazar.studio:10022/nazar/nazar.git
```

If Forgejo app state was not preserved, recreate users/repos from bundles according to the Forgejo service runbook.

### 18.3 Minecraft validation

```bash
ssh alex@10.10.10.30 'systemctl is-active minecraft-server; systemctl --failed --no-pager'
ssh alex@10.10.10.30 'journalctl -u minecraft-server -n 100 --no-pager'
```

If public Minecraft remains enabled:

```bash
dig +short mc.nazar.studio A @1.1.1.1
nc -vz mc.nazar.studio 25565
curl -fsS https://api.mcstatus.io/v2/status/java/mc.nazar.studio | jq .
```

UDP voice check requires a real client or UDP-aware probe.

### 18.4 OwnLoom validation

```bash
ssh alex@10.10.10.40 'pi --help >/dev/null; ownloom-context --format json >/dev/null'
ssh alex@10.10.10.40 'systemctl is-active ownloom-web nginx ownloom-zellij-web'
curl -fsS http://ownloom.nazar.studio/api/health | jq .
```

Confirm OwnLoom remains private-only. No public NAT/forwarding should expose it.

### 18.5 OwnLoom Data validation

```bash
ssh alex@10.10.10.41 'systemctl is-active radicale nginx'
ssh alex@10.10.10.41 'systemctl list-timers ownloom-wiki-git-backup.timer --no-pager'
curl -sS -o /dev/null -w '%{http_code}\n' http://data.nazar.studio/files/
```

Expected unauthenticated status for `/files/`: `401`.

Run an authenticated WebDAV/Radicale check only with credentials from the password manager or secret store.

---

## 19. Host rebuild and deploy model after migration

Initial recommendation for NixOS+microVM:

- Host flake owns MicroVM definitions.
- Host rebuild activates infrastructure/networking/MicroVM config.
- VM/service repos still own application modules and packages.
- VM-local self-deploy can be reintroduced later as a restricted trigger for only that guest.

Host-local rebuild:

```bash
ssh alex@$NAZAR_NB_IP
cd /srv/nazar
sudo nixos-rebuild switch --flake .#nazar
```

Laptop-driven rebuild over NetBird:

```bash
cd ~/src/nazar-stack/nazar
nixos-rebuild switch \
  --flake .#nazar \
  --target-host alex@$NAZAR_NB_IP \
  --use-remote-sudo
```

If service inputs are still local path overrides during bootstrap, preserve that consciously and do not accidentally commit a bootstrap lock unless desired.

---

## 20. NetBird/DNS policy update

If the host receives a new NetBird IP:

1. update NetBird peer name to `nazar` / `nazar.netbird.cloud` equivalent;
2. update NetBird custom DNS records:
   - `nazar.studio`;
   - `git.nazar.studio`;
   - `ownloom.nazar.studio`;
   - `data.nazar.studio`;
   - any dashboard aliases;
3. update NetBird policies to keep least privilege;
4. remove old/dead peers after validation.

Do not add broad admin-to-guest SSH policies unless explicitly approved.

---

## 21. Backups after migration

Proxmox `vzdump` is gone after this migration. Replace it with explicit backups of:

```text
/srv/nazar or chosen infra checkout
/persist/microvms/git
/persist/microvms/minecraft
/persist/microvms/ownloom
/persist/microvms/ownloom-data
/persist/secrets, if secrets are stored there
```

Minimum acceptance before deleting old backup archives:

```text
[ ] new host backup job exists declaratively
[ ] backup timer ran successfully
[ ] backup logs are clean
[ ] restore of at least one repo bundle tested
[ ] restore of at least one service state archive tested to a disposable path
[ ] old Proxmox backups retained off-host until new restore proof exists
```

Recommended future tools: restic, borg, ZFS/btrfs snapshots plus off-host copy, or another explicit backup target. Choose one and document exact restore commands.

---

## 22. Rollback plan

Rollback is acceptable until the new host is declared stable.

Options:

1. **Config-only failure:** boot previous NixOS generation from GRUB if reachable, or use Rescue to edit/rebuild.
2. **NixOS host install failure:** boot Hetzner Rescue, fix config, rerun `nixos-anywhere`.
3. **Migration failure:** reinstall Debian/Proxmox via Hetzner/previous method and restore old VM backups.
4. **Total host unavailable:** restore repos and service state to another machine from off-host backups.

Keep old off-host archives until:

- NixOS host survives reboot;
- NetBird reconnects after reboot;
- all selected MicroVMs autostart;
- services pass health checks;
- new backup job has completed;
- at least one restore test succeeds.

---

## 23. Acceptance criteria

The migration is complete only when all are true:

```text
[ ] `alex` can SSH to host over NetBird.
[ ] `alex` has passwordless sudo.
[ ] root is not used for daily operation.
[ ] public SSH is closed.
[ ] NetBird reconnects after reboot.
[ ] host firewall exposes only approved public ports.
[ ] MicroVMs start declaratively.
[ ] git service is reachable over private path.
[ ] all required repos are restored and push/pull works.
[ ] Minecraft state is either restored or intentionally reset.
[ ] OwnLoom is reachable privately and not publicly exposed.
[ ] OwnLoom Data DAV/Radicale works with auth.
[ ] secrets are not in git and have correct file modes.
[ ] backups run on the new host.
[ ] restore test is documented.
[ ] final production flake.lock no longer depends accidentally on laptop-only paths unless intentionally designed.
```

---

## 24. Appendix A: command checklist

### Laptop preflight

```bash
cd ~/src/nazar-stack/nazar
pi

git status --short --branch
nix flake metadata
nix flake check --no-build
nix build .#nixosConfigurations.nazar.config.system.build.toplevel
```

### Bootstrap local inputs

```bash
cp flake.lock flake.lock.before-local-bootstrap
nix flake lock \
  --override-input forgejo path:../forgejo \
  --override-input minecraft path:../minecraft \
  --override-input ownloom path:../ownloom \
  --override-input ownloom-data path:../ownloom-data
nix flake check --no-build
```

### Rescue verification

```bash
export NAZAR_IP=167.235.12.22
ssh root@$NAZAR_IP
ip -br addr
ip route
ip -6 route
lsblk -e7 -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
ls -l /dev/disk/by-id/ | grep -E 'nvme|ata|wwn' | sort
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS
```

### Install

```bash
cd ~/src/nazar-stack/nazar
export NAZAR_IP=167.235.12.22
nix run github:nix-community/nixos-anywhere -- \
  --print-build-logs \
  --generate-hardware-config nixos-generate-config ./nix/hosts/nazar/hardware-configuration.nix \
  --extra-files "$HOME/nazar-install-extra-files" \
  --flake .#nazar \
  --target-host root@$NAZAR_IP \
  -i ~/.ssh/id_ed25519
```

### First boot

```bash
ssh-keygen -R 167.235.12.22
ssh alex@$NAZAR_NB_IP
sudo -n true
systemctl --failed --no-pager
netbird status
nc -vz 167.235.12.22 22
```

### MicroVM validation

```bash
systemctl status 'microvm@*.service' --no-pager
ssh alex@10.10.10.21 'systemctl is-active forgejo'
ssh alex@10.10.10.30 'systemctl is-active minecraft-server'
ssh alex@10.10.10.40 'systemctl is-active ownloom-web nginx ownloom-zellij-web'
ssh alex@10.10.10.41 'systemctl is-active radicale nginx'
```

---

## 25. Appendix B: source references

- Hetzner Rescue System: <https://docs.hetzner.com/robot/dedicated-server/troubleshooting/hetzner-rescue-system/>
- Hetzner systemd-networkd dedicated server networking: <https://docs.hetzner.com/robot/dedicated-server/network/network-configuration-using-systemd-networkd/>
- Hetzner Debian/Ubuntu network notes: <https://docs.hetzner.com/robot/dedicated-server/network/net-config-debian-ubuntu/>
- NixOS Wiki, Hetzner Online: <https://wiki.nixos.org/wiki/Install_NixOS_on_Hetzner_Online>
- nixos-anywhere quickstart/reference: <https://nix-community.github.io/nixos-anywhere/>
- disko docs: <https://github.com/nix-community/disko>
- microvm.nix host/declarative/routed networking docs: <https://microvm-nix.github.io/microvm.nix/>
