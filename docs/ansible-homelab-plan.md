# Ansible Homelab Fleet Management Plan

## Overview

Standardize the management of Ubuntu 24.04 laptops using Ansible in push mode. This plan covers initial provisioning over temporary Ethernet and ongoing management via Tailscale MagicDNS.

## Scope

### Implemented Now
- Wi-Fi configuration via netplan
- Tailscale network join with `tag:dev`
- Disable all lid-close actions
- SSH key deployment and staged hardening
- Pragmatic security baseline (updates, firewall, fail2ban)

### Future Extensibility
- k3s cluster joining
- Dotfiles and userland tooling
- Additional security hardening
- New roles can be added without restructuring

## Operating Model (Push)

- **Control Node**: One machine holds the repo and runs all playbooks
- **Target Laptops**: Never clone the repo locally
- **Bootstrap**: Run over temporary Ethernet using temporary IP
- **Ongoing**: Manage hosts by Tailscale MagicDNS names

## Repository Structure

```
ansible/
├── ansible.cfg
├── collections/
│   └── requirements.yml
├── inventories/
│   └── homelab/
│       └── hosts.yml
├── group_vars/
│   ├── all.yml
│   ├── networking.yml
│   ├── security.yml
│   └── networking.vault.yml          # Encrypted secrets
├── playbooks/
│   ├── bootstrap.yml                  # First-run provisioning
│   ├── site.yml                     # Normal ongoing convergence
│   └── lockdown.yml                 # Final SSH hardening step
└── roles/
    ├── system/
    │   ├── tasks/
    │   ├── handlers/
    │   ├── templates/
    │   └── defaults/
    ├── networking/
    │   ├── tasks/
    │   ├── handlers/
    │   ├── templates/
    │   └── defaults/
    └── security/
        ├── tasks/
        ├── handlers/
        ├── templates/
        └── defaults/
```

## Role Responsibilities

### system
- Ensure base packages are present
- Configure lid behavior in `/etc/systemd/logind.conf`:
  - `HandleLidSwitch=ignore`
  - `HandleLidSwitchExternalPower=ignore`
  - `HandleLidSwitchDocked=ignore`
- Handler: restart `systemd-logind`

### networking
- Deploy netplan Wi-Fi template
- Safe apply flow: `netplan generate` then `netplan apply` via handler
- Install Tailscale and run `tailscale up` with `tag:dev`

### security
- Install SSH public keys with `authorized_key`
- SSH daemon settings with staged hardening
- Unattended security upgrades
- UFW baseline rules (allow SSH, allow Tailscale)
- Fail2ban for SSH protection

## Playbook Design

### bootstrap.yml (First-Run)
Run once per host over temporary Ethernet.

1. Preflight: Verify Ubuntu 24.04
2. Add SSH public key to target user
3. Configure Wi-Fi via netplan
4. Install and connect Tailscale (`tag:dev`)
5. Apply lid-close ignore settings
6. Apply safe baseline security (non-lockout changes only)

### site.yml (Ongoing Convergence)
Run regularly over Tailscale MagicDNS.

- Re-run `system`, `networking`, `security` idempotently
- Tags: `system`, `networking`, `security`

### lockdown.yml (Explicit Hardening)
Run manually after verifying key-based access works.

- Disable SSH password auth (`PasswordAuthentication no`)
- Reload SSH daemon
- Run with `serial: 1` for lockout safety

## Variable and Secrets Strategy

### group_vars/all.yml
- `admin_user`: Target login user on all laptops
- `timezone`: System timezone
- `base_packages`: Common packages to install
- Common toggles and defaults

### group_vars/networking.yml
- `wifi_ssid`: Shared Wi-Fi network name
- `wifi_interface`: Wi-Fi interface pattern or explicit name
- `tailscale_tags`: `['dev']`
- `tailscale_accept_dns`: Boolean

### group_vars/networking.vault.yml (Encrypted)
- `wifi_psk`: Wi-Fi password
- `tailscale_auth_key`: Tailscale authentication key

### group_vars/security.yml
- `ssh_public_keys`: List of public keys to deploy
- `ufw_enabled`: Boolean
- `fail2ban_enabled`: Boolean

### host_vars/
Reserved for per-host overrides. Keep minimal unless needed.

## Bootstrap and Rollout Runbook

### 1. Control Node Prep
- Install Ansible and required collections
- Set up Vault password strategy
- Prepare inventory with hostnames matching future MagicDNS names

### 2. Pilot One Laptop
Run bootstrap over temporary Ethernet:

```bash
ansible-playbook -i ansible/inventories/homelab/hosts.yml \
  ansible/playbooks/bootstrap.yml \
  -l <hostname> \
  -e ansible_host=<ethernet-ip> \
  --ask-become-pass \
  --ask-vault-pass
```

### 3. Validate Pilot
- [ ] Wi-Fi connects after unplugging Ethernet
- [ ] Host appears in Tailscale with `tag:dev`
- [ ] SSH key login works over MagicDNS
- [ ] Lid close does nothing (no suspend/shutdown)

### 4. Lockdown Pilot
After confirming key-based access:

```bash
ansible-playbook -i ansible/inventories/homelab/hosts.yml \
  ansible/playbooks/lockdown.yml \
  -l <hostname> \
  --ask-vault-pass
```

- [ ] Password auth is rejected
- [ ] Key auth still works

### 5. Expand to Fleet
Repeat bootstrap for remaining laptops, then converge all:

```bash
ansible-playbook -i ansible/inventories/homelab/hosts.yml \
  ansible/playbooks/site.yml \
  --ask-vault-pass
```

## Safety Controls

- **Never disable SSH passwords during bootstrap**
- Password auth disabled **only** in `lockdown.yml`
- Use handlers and idempotent modules everywhere
- Use `serial: 1` for SSH-affecting changes
- Keep secrets **only** in Vault-encrypted files
- Validate pilot thoroughly before fleet rollout

## Execution Commands Reference

### Install collections
```bash
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

### Bootstrap one host
```bash
ansible-playbook -i ansible/inventories/homelab/hosts.yml \
  ansible/playbooks/bootstrap.yml \
  -l <hostname> \
  -e ansible_host=<ethernet-ip> \
  --ask-become-pass \
  --ask-vault-pass
```

### Normal fleet convergence
```bash
ansible-playbook -i ansible/inventories/homelab/hosts.yml \
  ansible/playbooks/site.yml \
  --ask-vault-pass
```

### Lockdown after verification
```bash
ansible-playbook -i ansible/inventories/homelab/hosts.yml \
  ansible/playbooks/lockdown.yml \
  -l <hostname> \
  --ask-vault-pass
```

## Extensibility Plan

- Domain tags from day one: `--tags system`, `--tags networking`, `--tags security`
- Future roles can be added without restructuring:
  - `roles/userland` for dotfiles and tooling
  - `roles/k3s` for Kubernetes cluster joining
- Continue using `group_vars` + `host_vars` pattern for growth
- Pragmatic security baseline now; stricter hardening can be layered later

## Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Operating model | Push | Centralized management, no repo cloning on targets |
| Bootstrap connectivity | Temporary Ethernet | Reliable first-run access before Wi-Fi/Tailscale |
| Ongoing connectivity | Tailscale MagicDNS | Dynamic IPs handled automatically |
| OS scope | Ubuntu 24.04 only | Simplifies role logic and netplan handling |
| Host types | All laptops | Lid behavior applies uniformly |
| Wi-Fi strategy | One shared profile | All laptops connect to same network |
| Tailscale tags | `dev` | Consistent tagging for ACL policy |
| SSH auth sequence | Keys first, then disable passwords | Prevents lockout |
| Password disable | Separate `lockdown.yml` playbook | Explicit safety gate |
| Security baseline | Pragmatic | Good security gain with low breakage risk |
| k3s | Out of scope now | Structure supports adding it later |
| CI/CD | Out of scope | Manual runs for now |

## Open Questions Before Build

1. **Admin username**: What is the target login user on all laptops?
2. **SSH public key**: Which public key(s) should be deployed fleet-wide?
3. **Wi-Fi interface**: Should we auto-detect (`wlp*`) or use explicit interface names?
