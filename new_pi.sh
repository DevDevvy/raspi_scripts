#!/bin/bash

# Update and upgrade packages
sudo apt update && sudo apt upgrade -y

# Install necessary packages
sudo apt install -y zsh curl

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"



# Change default shell to Zsh
chsh -s $(which zsh)

# Additional security measures
# Enable firewall (ufw)
sudo apt install -y ufw
sudo ufw allow ssh
sudo ufw enable

# Install fail2ban for additional security against brute-force attacks
sudo apt install -y fail2ban

echo "Setup completed. Please reboot your Raspberry Pi."