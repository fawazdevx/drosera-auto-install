# 💀 Drosera Auto Install

**Just run this, you lazy f*ck:**

```bash
bash <(curl -s https://raw.githubusercontent.com/bezicalboy/drosera-auto-install/refs/heads/main/drosera.sh)
```

This script will:

- Set up your Drosera trap project
- Deploy it to Holesky
- Register your operator
- Set up the node as a systemd service
- Make you question why you ever did this manually

---

## 🧠 Change the Ethereum RPC (optional but smart)

By default, the service uses a public RPC.  
**I recommend you use [Alchemy](https://www.alchemy.com/)** or something equally reliable.

### ✍️ To change it:

```bash
sudo systemctl stop drosera
sudo nano /etc/systemd/system/drosera.service
```

> Find the `--eth-rpc-url` line and swap it with your preferred RPC URL.

### 🔁 Then reload and restart the service:

```bash
sudo systemctl daemon-reload
sudo systemctl start drosera
```

---

## 📟 View Logs Like a Hacker

```bash
journalctl -u drosera.service -f
```

---

## ⚠️ Warnings

- You **NEED** Holesky ETH to deploy the trap.
- You **MUST** send **Bloom Boost** before `dryrun`.
- You **WILL CRY** if you skip steps.

---

## 👋 Peace

Made with love, rage, and shell scripting by [`bezicalboy`](https://github.com/bezicalboy)
