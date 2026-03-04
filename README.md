Jubei-Samurai VPN
==================

Author: Hector Flores (Lamar University)  
Project name: **Jubei-Samurai**

> A self-hosted VPN based on WireGuard that encrypts your traffic and can be used from Windows, Linux Mint, and Android.

---

Legal & ethical notice
----------------------

- **You are responsible** for how you use this project.  
- Only use this VPN in compliance with **local laws** and the **terms of service** of the sites and services you access.  
- A VPN can help protect privacy and may allow access to region-specific content, but it **must not** be used to break the law or violate contracts.

---

High-level design
-----------------

- **Protocol**: WireGuard (modern, fast, secure VPN protocol).
- **Server**: A Linux server (e.g. Ubuntu) running a WireGuard interface `wg0` that:
  - Encrypts/decrypts VPN traffic.
  - Forwards packets from VPN clients to the internet.
  - Masquerades client traffic so it appears to come from the server's IP (hiding client IP/location).
- **Clients**:
  - **Windows**: Official WireGuard client.
  - **Linux Mint**: `wireguard-tools` (`wg-quick`) or Network Manager plugin.
  - **Android**: Official WireGuard app.

This repo gives you:

- Scripts to **set up the server** (`server/setup.sh`).
- **Configuration templates** for server and client peers.
- Documentation for using the configs on **Windows, Linux Mint, and Android**.

You will still need:

- A Linux server with a **public IP address** (e.g. a VPS in the region you want).
- Root (sudo) access to that server.

---

Project structure
-----------------

- `server/`
  - `setup.sh` – helper script to install WireGuard and prepare `wg0.conf`.
  - `wg0.conf.template` – base WireGuard server configuration.
- `clients/`
  - `jubei-samurai-client.conf.template` – example client config to import on Windows/Linux/Android.

---

1. Prepare your Linux VPN server
--------------------------------

Requirements (on the server):

- Linux distro (Debian/Ubuntu preferred).
- Root privileges (`sudo`).
- A static public IP or DNS name.

Steps:

1. Copy the `server/` directory from this project onto your Linux server (e.g. via `scp`).
2. SSH into the server.
3. Run:

   ```bash
   cd /path/to/server
   sudo bash setup.sh
   ```

4. The script will:
   - Install WireGuard packages (on Debian/Ubuntu-like systems).
   - Ask you for:
     - VPN interface address (e.g. `10.8.0.1/24`).
     - UDP listen port (e.g. `51820`).
   - Generate server keys.
   - Create `/etc/wireguard/wg0.conf` from `wg0.conf.template`.
   - Enable IP forwarding and basic NAT (iptables or nftables).

5. Start the VPN:

   ```bash
   sudo systemctl enable wg-quick@wg0
   sudo systemctl start wg-quick@wg0
   ```

If everything is correct, your server is now acting as a VPN endpoint.

---

2. Create a client configuration
--------------------------------

On the server:

1. Generate a client keypair:

   ```bash
   wg genkey | tee client-private.key | wg pubkey > client-public.key
   ```

2. Add the client as a peer in `/etc/wireguard/wg0.conf` (example):

   ```ini
   [Peer]
   # Jubei-Samurai client
   PublicKey = <CLIENT_PUBLIC_KEY>
   AllowedIPs = 10.8.0.2/32
   ```

3. Restart WireGuard:

   ```bash
   sudo systemctl restart wg-quick@wg0
   ```

4. Create a client config from `clients/jubei-samurai-client.conf.template`, filling in:

   - `<SERVER_PUBLIC_KEY>`
   - `<SERVER_PUBLIC_IP_OR_DNS>`
   - `<CLIENT_PRIVATE_KEY>`
   - `<VPN_CLIENT_IP>` (e.g. `10.8.0.2/32`)

You can maintain one config per device (Windows laptop, Linux Mint desktop, Android phone, etc.).

---

3. Using Jubei-Samurai on Windows
---------------------------------

1. Download and install the official WireGuard client for Windows from the WireGuard project website.
2. Transfer your filled-in client config file (e.g. `jubei-samurai-windows.conf`) to the Windows machine.
3. In the WireGuard app:
   - Click **Add Tunnel** → **Import from file**.
   - Select the config file.
4. Click **Activate** to connect.

When connected:

- Your traffic is encrypted between your Windows machine and the VPN server.
- External sites see the server's IP address, not your home IP.

---

4. Using Jubei-Samurai on Linux Mint
------------------------------------

Option A – `wg-quick`:

1. On Linux Mint, install:

   ```bash
   sudo apt update
   sudo apt install wireguard
   ```

2. Copy your client config to `/etc/wireguard/jubei-samurai.conf` (root required).
3. Bring the interface up:

   ```bash
   sudo wg-quick up jubei-samurai
   ```

4. To bring it down:

   ```bash
   sudo wg-quick down jubei-samurai
   ```

Option B – Network Manager plugin (alternative UI-based method) can also be used if installed, by importing the same `.conf` file.

---

5. Using Jubei-Samurai on Android
---------------------------------

1. Install the **WireGuard** app from the Google Play Store.
2. Transfer your client config to the phone or create a QR code from the config.
3. In the app:
   - Tap **+** → **Import from file or archive** (or scan QR).
   - Select your client config.
4. Toggle the tunnel **ON** to connect.

While connected:

- All traffic allowed by the config passes through your VPN server.
- Your apparent IP/location to websites is that of the server.

---

6. Security & privacy notes
---------------------------

- **Keep keys secret**: Never share your private keys or configs publicly.
- **Server hardening**:
  - Keep your server OS updated.
  - Use a firewall to limit access (e.g. only WireGuard UDP port open).
  - Use strong SSH access controls.
- **Logging**:
  - WireGuard itself is minimalist, but your server OS, DNS resolvers, and apps may log traffic.
  - Review and adjust logs according to your privacy needs and legal requirements.

---

7. Geo-location and restrictions
--------------------------------

- The VPN server's **physical location** (its IP address) determines how most services see your region.
- This can allow access to **region-specific content**, but:
  - Some services actively **block VPN IPs**.
  - Many services have **terms of use** about location and licensing.

---

8. Next steps / customization
-----------------------------

- Add multiple client peers to `/etc/wireguard/wg0.conf` (one per device).
- Tune firewall and routing rules for split-tunneling (route only some traffic through VPN).
- Automate config generation with your own scripts or management UI.

This project gives you a clean, minimal starting point. From here, you can grow **Jubei-Samurai** into a full-featured VPN solution that fits your needs.

