#!/bin/bash

# Check if drosera_operator exists and remove it
if [ -d "drosera_operator" ]; then
  echo "Removing drosera_operator directory..."
  rm -rf "drosera_operator"
fi

# Check if my_trap_drosera exists and remove it
if [ -d "my_trap_drosera" ]; then
  echo "Removing my_trap_drosera directory..."
  rm -rf "my_trap_drosera"
fi

echo "🌿 Hella One Click"
echo "🚀 Drosera Full Auto Install (SystemD Only)"

# === 1. User Inputs ===
read -p "📧 GitHub email: " GHEMAIL
read -p "👤 GitHub username: " GHUSER
read -p "🔐 Drosera private key (0x...): " PK
read -p "🌍 VPS public IP: " VPSIP
read -p "📬 Public address for whitelist (0x...): " OP_ADDR

for var in GHEMAIL GHUSER PK VPSIP OP_ADDR; do
  if [[ -z "${!var}" ]]; then
    echo "❌ $var is required."
    exit 1
  fi
done

# === 2. Install Dependencies ===
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip -y

# === 3. Install Drosera CLI ===
curl -L https://app.drosera.io/install | bash
source ~/.bashrc
droseraup

# === 4. Install Foundry ===
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# === 5. Install Bun ===
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# === 6. Set Up Trap ===
mkdir -p ~/my-drosera-trap && cd ~/my-drosera-trap
git config --global user.email "$GHEMAIL"
git config --global user.name "$GHUSER"
forge init -t drosera-network/trap-foundry-template
bun install && forge build

# === 7. Deploy Trap ===
echo "🚀 Deploying trap to Holesky..."
LOG_FILE="/tmp/drosera_deploy.log"
DROSERA_PRIVATE_KEY=$PK drosera apply <<< "ofc" | tee "$LOG_FILE"

TRAP_ADDR=$(grep -oP '(?<=address: 0x)[a-fA-F0-9]{40}' "$LOG_FILE" | head -n 1)
TRAP_ADDR="0x$TRAP_ADDR"

if [[ -z "$TRAP_ADDR" || "$TRAP_ADDR" == "0x" ]]; then
  echo "❌ Failed to detect trap address."
  exit 1
fi

echo "🪤 Trap deployed at: $TRAP_ADDR"

# === 8. Whitelist Operator ===
echo "🔐 Updating drosera.toml with whitelist..."
sed -i '/^whitelist/d' drosera.toml
echo -e 'private_trap = true
whitelist = ["'"$OP_ADDR"'"]' >> drosera.toml

# === 9. Wait & Reapply ===
echo "⏳ Waiting 10 minutes before re-applying config with whitelist..."
sleep 600
DROSERA_PRIVATE_KEY=$PK drosera apply <<< "ofc" | tee "$LOG_FILE"

# === 10. Download Operator Binary ===
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin && chmod +x /usr/bin/drosera-operator

# === 11. Register Operator ===
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $PK

# === 12. Setup SystemD ===
echo "🛠️ Setting up systemd service..."
USER=$(whoami)
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

# === 13. Start Service ===
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

# === 14. Bloom Boost ===
echo "⚡ Sending Bloom Boost to trap: $TRAP_ADDR"
DROSERA_PRIVATE_KEY=$PK drosera bloomboost --trap-id $TRAP_ADDR --eth-amount 0.01

# === 15. Opt-in ===
echo "🔗 Opting in operator to trap..."
drosera-operator optin --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $PK --trap-config-address $TRAP_ADDR

# === 16. Dryrun ===
cd ~/my-drosera-trap
drosera dryrun

# === 17. Done ===
echo ""
echo "✅ Setup complete."
echo "🪤 Trap: https://app.drosera.io/trap?trapId=$TRAP_ADDR"
echo "📖 Logs: journalctl -u drosera -f"
