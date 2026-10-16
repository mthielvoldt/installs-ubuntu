## Setting up Ubuntu droplet

### As root
```
adduser mike                       # set a password: sudo will ask for it
usermod -aG sudo mike
rsync --archive --chown=mike:mike ~/.ssh /home/mike   # same SSH key now works for mike
```

Before closing the root session, open a second terminal and check that ssh mike@<droplet> works and sudo -v accepts your
password. Only then lock root out:

```
cat > /etc/ssh/sshd_config.d/10-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
EOF
sshd -t && systemctl reload ssh     # sshd -t validates the config first
```

Then a basic firewall, leaving SSH open:

```
ufw allow OpenSSH
ufw enable
```

Port 443 gets opened later, when the report is served over the web. Ubuntu droplets already have automatic security
updates on (unattended-upgrades).
