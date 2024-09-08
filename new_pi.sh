#!/bin/bash

# Error handling function
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    handle_error "Please run as root or use sudo"
fi

echo "Starting Kali Linux basic security setup for pentesting..."

# Update package lists and upgrade existing packages
apt update && apt upgrade -y || handle_error "Failed to update and upgrade packages"

# Install necessary packages (removed tor and torbrowser-launcher)
apt install -y git zsh ufw fail2ban apparmor gnupg tmux snapd clamav chkrootkit rkhunter lynis dnscrypt-proxy || handle_error "Failed to install required packages"

# Determine the user who executed the script with sudo
SUDO_USER=${SUDO_USER:-${USER}}
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

# Install Zsh and Oh My Zsh for the user
echo "Installing Oh My Zsh for $SUDO_USER"
su - $SUDO_USER -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' || handle_error "Failed to install Oh My Zsh"

# Install Zsh plugins
echo "Installing Zsh plugins"
su - $SUDO_USER -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'
su - $SUDO_USER -c 'git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'

# Enable Zsh plugins in .zshrc
echo "Enabling Zsh plugins in .zshrc"
su - $SUDO_USER -c 'sed -i "s/plugins=(git)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/" ~/.zshrc'

# Enable and start AppArmor
echo "Enabling AppArmor"
systemctl enable apparmor || handle_error "Failed to enable AppArmor"
systemctl start apparmor || handle_error "Failed to start AppArmor"

# Configure UFW for pentesting (allowing all outgoing and essential incoming)
echo "Configuring UFW for pentesting"
ufw default allow outgoing
ufw default deny incoming
ufw allow 22/tcp  # SSH
ufw allow 80/tcp  # HTTP
ufw allow 443/tcp # HTTPS
ufw enable || handle_error "Failed to enable UFW"

# Enable Fail2Ban
echo "Configuring Fail2Ban"
systemctl enable fail2ban || handle_error "Failed to enable Fail2Ban"
systemctl start fail2ban || handle_error "Failed to start Fail2Ban"

# Setup ClamAV
echo "Setting up ClamAV"
systemctl enable clamav-freshclam || handle_error "Failed to enable ClamAV"
systemctl start clamav-freshclam || handle_error "Failed to start ClamAV"
freshclam || handle_error "Failed to update ClamAV virus database"

# Configure rootkit detection tools
echo "Configuring rootkit detection tools"
chkrootkit || echo "chkrootkit completed with warnings, please review the output"
rkhunter --update || handle_error "Failed to update rkhunter"
rkhunter --propupd || handle_error "Failed to update rkhunter properties"

# Run Lynis for security auditing
echo "Running Lynis for initial security audit"
lynis audit system || echo "Lynis audit completed with warnings, please review the output"

# Setup Snapd
echo "Installing and enabling snapd"
systemctl enable --now snapd.socket || handle_error "Failed to enable snapd"
ln -s /var/lib/snapd/snap /snap 2>/dev/null || true

# Configure DNSCrypt with secure resolvers
echo "Configuring DNSCrypt with secure resolvers"
cat << EOF > /etc/dnscrypt-proxy/dnscrypt-proxy.toml
server_names = ['cloudflare', 'google', 'quad9-dnscrypt-ip4-filter-pri']
listen_addresses = ['127.0.0.1:53', '[::1]:53']
max_clients = 250
ipv4_servers = true
ipv6_servers = false
dnscrypt_servers = true
doh_servers = true
require_dnssec = true
require_nolog = true
require_nofilter = true
force_tcp = false
timeout = 2500
keepalive = 30
log_level = 2
use_syslog = true
cert_refresh_delay = 240
fallback_resolver = '9.9.9.9:53'
ignore_system_dns = true
netprobe_timeout = 60
cache = true
cache_size = 4096
cache_min_ttl = 2400
cache_max_ttl = 86400
cache_neg_min_ttl = 60
cache_neg_max_ttl = 600
[static]
[static.'cloudflare']
stamp = 'sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5'
[static.'google']
stamp = 'sdns://AgUAAAAAAAAABzguOC44LjigHvYkz_9ea9O63fP92_3qVlRn43cpncfuZnUWbzAMwbkgdoAkR6AZkxo_AEMExT_cbBssN43Evo9zs5_ZyWnftEUKZG5zLmdvb2dsZQovZG5zLXF1ZXJ5'
[static.'quad9-dnscrypt-ip4-filter-pri']
stamp = 'sdns://AQMAAAAAAAAADTkuOS45LjExOjg0NDMgZ8hHuMh1jNEgJFVDvnVnRt803x2EwAuMRwNo34Idhj4ZMi5kbnNjcnlwdC1jZXJ0LnF1YWQ5Lm5ldA'
EOF

systemctl enable dnscrypt-proxy || handle_error "Failed to enable DNSCrypt"
systemctl restart dnscrypt-proxy || handle_error "Failed to start DNSCrypt"

# Configure system to use DNSCrypt
echo "nameserver 127.0.0.1" > /etc/resolv.conf

echo "Kali Linux basic security setup for pentesting complete!"
echo "Please restart your system to apply all changes."