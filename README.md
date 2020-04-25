# LEMP Ubuntu Utils Scripts

"LEMP Ubuntu Utils Scripts" is a **BASH** script which can be used to automate backups (files and databases), restore backups, create clean installation of WordPress Projects, and other useful tasks.
It's written in BASH scripting language.

## Main Features

* File backups
* Database backups (MySQL or MariaDB)
* Upload backups to Dropbox (API v2)
* Restore backups
* LEMP automated installer
* WordPress automated installer
* WP-CLI actions helper
* Monit installer and configuration helper
* Netdata installer and configuration helper
* Certbot installer and configuration helper
* Cockpit installer and configuration helper
* Cloudflare support
* PHP optimization tool (beta)
* Image optimization tool
* Blacklist checker
* Benchmark tools
* Simple step-by-step configuration wizard

## Supports

Works on Ubuntu 18.04 LTS and Ubuntu 20.04 LTS (partial support)

## Getting started

Give the execution permission to the script and run it:

```bash
 $chmod +x runner.sh
```

The first time you run `runner.sh`, you'll be guided through a wizard in order to configure it. This configuration will be stored in `~/.broobe-utils-script`.

## Running as cron job
This script relies on a different configuration file for each system user. The default configuration file location is `root/.broobe-utils-script`.
This means that if you setup the script with your user and then you try to run a cron job as root, it won't work.
So, when running this script using cron, please keep in mind the following:
* Remember to setup the script with the user used to run the cron job
* Always specify the full script path when running it (e.g.  /path/to/dropbox_uploader.sh)
