# Easy Teslamate

This tool allows you to quickly set up, maintain, and upgrade a minimal stack
for [Teslamate](https://github.com/teslamate-org/teslamate) with SSL, password protection, Gzip compression, support
of Chinese vehicles, which can be hosted on a public server or your own computer with a Unix-like operating system
supported by Docker (tested on Ubuntu and MacOS). If you want to host Teslamate on a public server, buy a domain name
and set up a DNS record pointing to this server's IP address (you can also use a subdomain like teslamate.example.com).

## Installation

1. If you chose to host Teslamate on a public server, connect to this server via SSH, log in as root if needed, and
   upgrade the server in order to have the latest packages and security updates. For example, on Ubuntu, you can do this
   by running:
   ```
   sudo --login
   apt update && apt upgrade -y
   ```

2. Make a directory where you want to install Teslamate and to the directory, for example:
   ```
   mkdir -p ~/teslamate
   cd ~/teslamate
   ```

3. Configure and up the stack:
   ```
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

## Uninstallation

If you want to uninstall the stack, just down the stack and remove volumes by the following command and then remove the
directory where you installed Teslamate: ```docker compose --file services.yml down --volumes```