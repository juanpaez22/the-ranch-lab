# Ubuntu laptop preflight

Run on each Ubuntu laptop separately. These are manual procedures, not a record that they have been applied.

## Updates and reboot

Inspect the baseline:

```bash
hostnamectl
df -h /
systemctl --failed
```

Review and install normal package updates:

```bash
sudo apt update
apt list --upgradable
sudo apt upgrade
```

Review proposed changes before accepting. Investigate held packages separately; major distribution upgrades and firmware updates are separate tasks.

Reboot when ready, then reconnect over SSH:

```bash
sudo reboot
```

After reconnecting:

```bash
uptime
uname -r
systemctl --failed
ip -br address
df -h /
```

Verify access without a local login and name resolution between hosts. Do not paste raw network output into public logs. Package updates have no universal rollback; preserve important data before updating and investigate failures before further changes.

## Closed-lid operation

The [configuration](../configs/ubuntu/60-lid.conf) tells systemd-logind to ignore lid closure on external power or when docked, and suspend on battery when undocked. It does not disable idle suspend. A desktop power manager can take over lid handling, so test the result.

Requires Ubuntu with systemd-logind and administrative access. From the repository root on the target laptop, inspect existing settings:

```bash
systemd-analyze cat-config systemd/logind.conf
```

Check for an existing `/etc/systemd/logind.conf.d/60-lid.conf`. If present, compare it and save a copy outside the repository before replacing it. Other drop-ins may override these settings.

Apply:

```bash
sudo install -d -m 0755 /etc/systemd/logind.conf.d
sudo install -m 0644 configs/ubuntu/60-lid.conf /etc/systemd/logind.conf.d/60-lid.conf
sudo reboot
```

After reconnecting over SSH, plug in the laptop, close the lid, wait at least 30 seconds, and run `uptime`. Verify it remains reachable. Check ventilation with the lid closed.

To roll back a newly added file:

```bash
sudo rm /etc/systemd/logind.conf.d/60-lid.conf
sudo reboot
```

If the file replaced a previous configuration, restore that saved copy instead, then reboot.

Reference: [Ubuntu systemd-logind manual](https://manpages.ubuntu.com/manpages/noble/man5/logind.conf.d.5.html).
