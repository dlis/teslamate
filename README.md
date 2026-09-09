# Easy TeslaMate

This tool allows you to quickly set up a stack for [TeslaMate](https://github.com/teslamate-org/teslamate) with
the following features (tested on MacOS and Ubuntu):

- automatic HTTPS for localhost and a public server with compression (Zstd/Gzip),
- automatic password generation and only one long password (30 characters),
- only the necessary containers (for example, MQTT is disabled),
- optional Cloudflare tunnel instead of opening the ports 80 and 443,
- support for Chinese vehicles.

*An important note: if you want to host TeslaMate on a public server, buy a domain name and set up a DNS record pointing
to this server's IP address (you can also use a subdomain like teslamate.example.com). If you want to use a Cloudflare
tunnel, add the domain name itself (example.com, even if TeslaMate will be hosted on its subdomain) to your Cloudflare
account instead of the DNS record: the record will be created by the tunnel, and the tunnel does not need a public IP
address or open ports at all. Note that a free Cloudflare certificate covers only one level of subdomains, so
teslamate.example.com works, but teslamate.home.example.com does not.*

## Installation

1. If you chose to host TeslaMate on a public server, connect to this server via SSH, log in as root if needed, and
   upgrade the server in order to have the latest packages and security updates. For example, on Ubuntu, you can do this
   by running:
   ```
   sudo --login
   apt update && apt upgrade -y
   ```

2. Make the directory where you want to install TeslaMate, for example:
   ```
   mkdir -p ~/teslamate
   ```

3. If you want to use a Cloudflare tunnel, create it before the installation: in the Cloudflare dashboard, go to "Zero
   Trust" – "Networks" – "Tunnels", create a tunnel of the type "Cloudflared", add a public hostname with your domain
   name (a subdomain, if any, goes to "Subdomain"), the type "HTTP" and the URL "caddy:80", and copy the token of
   the tunnel (the long string after "--token" in the shown command). Do not run that command, the tunnel will be
   run by this tool. The tunnel stays offline until the installation is finished.

4. If you have the backup of the database, copy the backup named as "database.tmp" to the directory:
   ```
   cp path_to/your_backup ~/teslamate/database.tmp
   ```

5. Go to a directory where you want to install TeslaMate and configure the stack:
   ```
   cd ~/teslamate
   bash -c "$(curl -sSL https://github.com/dlis/teslamate/raw/master/install.sh)"
   ```

The file structure created by this tool during installation is as follows:

```
/
├── settings.env  (different settings)
└── services.yml  (stack of containers)
```

## Maintenance

If you want to change the domain name (when you host TeslaMate on a public server), username, timezone, or the way the
traffic reaches the server, just edit the file named "settings.env", and re-configure the stack as shown in the last
step of the installation instructions. If you want to upgrade the stack, just re-configure the stack. If you forgot the
password, just re-configure the stack and a new password will be generated. Note that re-configuring the stack always
generates a new password, so log in again in the browser tabs which were opened before it.

If you want to switch between opening the ports 80 and 443 and using a Cloudflare tunnel, put the token of the tunnel
into the setting named "TUNNEL" to use the tunnel or leave that setting empty to open the ports, and re-configure the
stack. If your "settings.env" was created before this setting appeared, add the line "TUNNEL=" to it. Note that a tunnel
requires a public domain name, it cannot be used with localhost.

If you want to create a backup of the database, you can do it by running the following command (the backup is
readable by you only, keep it that way, and keep a copy of "settings.env" with it because the data is encrypted with
a key from that file):
```(umask 077; docker compose --file services.yml exec -T database pg_dump -U teslamate teslamate > ./database.bck)```

To restore that backup, rename it to "database.tmp" and re-configure the stack. Keep the backup under any other name,
otherwise it will be restored on the next re-configuration of the stack, replacing the current data.

## Uninstallation

If you want to uninstall the stack, just down the stack and remove volumes by the following command and then remove the
directory where you installed TeslaMate: ```docker compose --file services.yml down --volumes``` If you used a
Cloudflare tunnel, also delete that tunnel in the Cloudflare dashboard.