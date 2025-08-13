# Easy Teslamate

This tool allows you to quickly set up a stack for [Teslamate](https://github.com/teslamate-org/teslamate) with
the following features (tested on MacOS and Ubuntu):

- automatic HTTPS for localhost and public server with Gzip compression,
- automatic password generation and only one long password (30 characters),
- only the necessary containers (for example, MQTT is disabled by disabled),
- support of Chinese vehicles.

*An important note: if you want to host Teslamate on a public server, buy a domain name and set up a DNS record pointing
to this server's IP address (you can also use a subdomain like teslamate.example.com).*

## Installation

1. If you chose to host Teslamate on a public server, connect to this server via SSH, log in as root if needed, and
   upgrade the server in order to have the latest packages and security updates. For example, on Ubuntu, you can do this
   by running:
   ```
   sudo --login
   apt update && apt upgrade -y
   ```

2. Make the directory where you want to install Teslamate and to the directory, for example:
   ```
   mkdir -p ~/teslamate
   ```

3. Go to a directory where you want to install Teslamate and configure and up the stack:
   ```
   cd ~/teslamate
   bash -c "$(curl -sSL https://github.com/dlis/teslamate/raw/master/install.sh)"
   ```

A file structure created by this tool during installation or using is as follows:

```
/
├── settings.env  (different settings)
└── services.yml  (stack of containers)
```

## Maintenance

If you want to change the domain name (when you host Teslamate on a public server), username, or timezone, just edit the
file named "settings.env", and re-configure the stack as shown in the last step of the installation instructions. If you
want to upgrade the stack just re-configure the stack. If you forgot the password, just re-configure the stack and new
password will be generated.

If you want to create a backup of the database, you can do it by running the following command:
```docker compose --file services.yml exec -T database pg_dump -U teslamate teslamate > ./teslamate.bck```

## Uninstallation

If you want to uninstall the stack, just down the stack and remove volumes by the following command and then remove the
directory where you installed Teslamate: ```docker compose --file services.yml down --volumes```