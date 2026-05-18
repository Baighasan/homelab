# Homelab

Simple homelab setup for four Ubuntu 24.04 laptops:
- **Ansible** for machine provisioning and ongoing config
- **Dotfiles** for shell/editor/CLI tooling

---

## 1) Ansible (fleet management)

### Summary
This repo manages a small laptop fleet in **push mode**:
- One control machine runs Ansible
- Targets do not need this repo cloned locally
- First run is done with temporary Ethernet access
- Ongoing management happens over Tailscale hostnames

Playbooks:
- `ansible/playbooks/bootstrap.yml` - first-time provisioning
- `ansible/playbooks/site.yml` - normal convergence
- `ansible/playbooks/lockdown.yml` - disable SSH password auth (after key access is verified)

Roles:
- `system` - base packages + lid-close behavior
- `networking` - Wi-Fi netplan + Tailscale join
- `security` - SSH keys, UFW, fail2ban, unattended upgrades

Vault:
- Ensure vault password is located in file at ansible/.homelab.vault.password
- This is automatically searched for when a playbook is run

### Fleet diagram

```text
                      +---------------------+
                      |   Control Machine   |
                      |  runs ansible CLI   |
                      +----------+----------+
                                 |
                                 | push over SSH / Tailscale
                                 v
      +----------------+   +----------------+   +----------------+   +----------------+
      |   lenovo-1     |   |   lenovo-2     |   |   thinkpad-1   |   |      dev       |
      | Ryzen 5 4500U  |   | i7-8565U       |   | i7-7500U       |   | i9-9880H       |
      | 8 GB RAM       |   | 16 GB RAM      |   | 16 GB RAM      |   | 32 GB RAM      |
      |                |   | Intel UHD 620  |   |                |   | Quadro T2000   |
      |                |   | Radeon 540X    |   |                |   |                |
      +----------------+   +----------------+   +----------------+   +----------------+
```

### Inventory
Hosts are defined in `ansible/inventories/hosts.yml`:
- `dev`
- `lenovo-1`
- `lenovo-2`
- `thinkpad-1`

### Common commands

Install required collections:
```bash
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

Bootstrap one machine (first run, typically over temporary Ethernet):
```bash
ansible-playbook ansible/playbooks/bootstrap.yml \
  -l <host> \
  -e ansible_host=<temporary-ip> \
```

Converge all machines:
```bash
ansible-playbook ansible/playbooks/site.yml
```

Run only one role:
```bash
ansible-playbook ansible/playbooks/site.yml --tags networking
```

Lock down SSH password auth (after key login is confirmed):
```bash
ansible-playbook ansible/playbooks/lockdown.yml -l <host>
```

Dry run:
```bash
ansible-playbook ansible/playbooks/site.yml --check --diff
```

---

## 2) Dotfiles

### Summary
Dotfiles are managed with GNU Stow from `dotfiles/` and cover:

- `zsh` (`.zshrc`)
- `p10k` (`.p10k.zsh`)
- `git` (`.gitconfig`)
- `tmux` (`.tmux.conf`)
- `nvim` (`.config/nvim`)
- `opencode` (`.config/opencode`)

### Apply dotfiles
From repo root:

```bash
cd dotfiles
stow -t ~ zsh p10k git nvim tmux opencode
```

### Bootstrap helper
`bootstrap.sh` installs base tools and applies stowed dotfiles automatically.

---

## Notes
- Intended OS: **Ubuntu 24.04**
- Sensitive values (Wi-Fi password, Tailscale auth key) are kept in Ansible Vault files
- Start with one machine, validate access, then roll out to the rest
