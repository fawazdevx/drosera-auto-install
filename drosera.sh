#!/bin/bash

echo "hella one click"
echo "Drosera auto install"

# 1. User inputs
read -p "Enter your GitHub email: " GHEMAIL
read -p "Enter your GitHub username: " GHUSER
read -p "Enter your Drosera private key (starts with 0x): " PK
read -p "Enter your VPS public IP: " VPSIP

if [[ -z "$PK" || -z "$VPSIP" || -z "$GHEMAIL" || -z "$GHUSER" ]]; then
  echo "❌ Missing info. All fields are required."
  exit 1
fi

# 2. Install dependencies
echo "📦 Installing dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

# 3. Install Drosera CLI
curl -L https://app.drosera.io/install | bash
source ~/.bashrc
droseraup

# 4. Install Foundry CLI
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# 5. Install Bun
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# 6. Set up drosera trap project
mkdir -p ~/my-drosera-trap && cd ~/my-drosera-trap
git config --global user.email "$GHEMAIL"
git config --global user.name "$GHUSER"
forge init -t drosera-network/trap-foundry-template

# 7. Build trap
bun install
forge build

# 8. Deploy Trap (1st apply)
echo "Deploying trap to Holesky, your wallet need balance of holesky eth buddy"
LOG_FILE="/tmp/drosera_deploy.log"
DROSERA_PRIVATE_KEY=$PK drosera apply <<< "ofc" | tee "$LOG_FILE"

# Extract trap address from log
TRAP_ADDR=$(grep -oP '(?<=address: 0x)[a-fA-F0-9]{40}' "$LOG_FILE" | head -n 1)
TRAP_ADDR="0x$TRAP_ADDR"

if [[ -z "$TRAP_ADDR" || "$TRAP_ADDR" == "0x" ]]; then
  echo "❌ Failed to detect trap address from terminal output."
  exit 1
fi

echo "🕳️ Trap created at: $TRAP_ADDR"

# 9. Add whitelist if not present
echo "Whitelisting operator..."
cd ~/my-drosera-trap
read -p "📬 Enter the PUBLIC address linked to your used private key (starts with 0x): " OP_ADDR

if [[ -z "$OP_ADDR" ]]; then
  echo "❌ Public address is required to whitelist operator."
  exit 1
fi

# Remove duplicate whitelist keys if exist
sed -i '/^whitelist/d' drosera.toml
echo -e '
private_trap = true
whitelist = ["'"$OP_ADDR"'"]' >> drosera.toml

# 10. Delay and reapply
echo "⏳ Waiting 10 minutes before re-applying config with whitelist..."
sleep 600

echo "Re-applying trap config with whitelist..."
DROSERA_PRIVATE_KEY=$PK drosera apply <<< "ofc" | tee "$LOG_FILE"

# Check for duplicate key error
if grep -q "duplicate key: whitelist" "$LOG_FILE"; then
  echo "⚠️ Already whitelisted. Continuing anyway..."
fi

# 11. Download operator binary
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin
chmod +x /usr/bin/drosera-operator

# 12. Register operator
echo "Registering operator..."
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $PK

# 13. Open ports
sudo ufw disable

# 14. Create systemd service
echo "Setting up systemd service..."

CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" != "root" ]; then
  USER=$CURRENT_USER
else
  USER="root"
fi

sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=/usr/bin/drosera-operator node --db-file-path /home/$USER/.drosera.db --network-p2p-port 31313 --server-port 31314 \\
    --eth-rpc-url https://holesky.drpc.org \\
    --eth-backup-rpc-url https://1rpc.io/holesky \\
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \\
    --eth-private-key $PK \\
    --listen-address 0.0.0.0 \\
    --network-external-p2p-address $VPSIP \\
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

# 15. Start systemd service
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

# 16. Bloom Boost
BLOOM_URL="https://app.drosera.io/trap?trapId=$TRAP_ADDR"
echo ""
echo "🌱 Your trap has been deployed at: $TRAP_ADDR"
echo "💸 You MUST send Bloom Boost to it before continuing."
echo "🧭 Go to this link in your browser and click 'Send Bloom Boost':"
echo ""
echo "👉 $BLOOM_URL"
echo ""
read -p "⏳ Press Enter once you've sent the Bloom Boost..."

# 17. Run dryrun
# 16. Run dryrun
echo "📡 Running drosera dryrun..."
drosera dryrun -c ~/my-drosera-trap/drosera.toml


# 18. Done
echo ""
echo "✅ All done. Node running via systemd."
echo "💻 Logs: journalctl -u drosera -f"
echo "🌐 Dashboard: https://app.drosera.io"
