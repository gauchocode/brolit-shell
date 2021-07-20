# BROLIT Shell

BROLIT Shell is a **BASH** based cloud server control software which can be used to quickly install a LEMP Stack on Ubuntu 18.04 and 20.04 servers, automate and restore backups, install PHP projects, and other IT tasks.

![ScreenShot](./screenshot.jpg)

## Motivation

* Standarize servers configuration.
* Automatization of IT/DevOps tasks.
* Reduce time and errors on IT/DevOps tasks.

## Why Bash?

* Performance.
* Pre-installed on linux systems.

## Why BROLIT Shell?

* Backup and restore projects easily.
* Create, deploy and host php projects.
* Option to run some taks from a single line command.
* Third party integrations: Dropbox, Cloudflare, Telegram, Netdata and more.
* WordPress support.
* Open-source.

## Features

* LEMP automated installer (Nginx, MySQL/MariaDB, PHP).
* Files and database backups (MySQL or MariaDB).
* Upload backups to Dropbox (API v2).
* Restore backups from Dropbox or URL.
* WordPress automated installer.
* WP-CLI actions helper.
* Let's Encrypt actions helper.
* Monit installer and configuration helper.
* Netdata installer and configuration helper.
* Certbot installer and configuration helper.
* Cloudflare support (via API).
* PHP-FPM optimization tool (beta).
* Image optimization tools.
* Fail2ban support.
* Security Tools with malware scanners.
* IP/Domain blacklist checker.
* Step-by-step configuration wizard.
* Benchmark tool.
* And more ...

## TODO List
[TODO List](./docs/TODO.md)

## Changelog
[Changelog](./docs/CHANGELOG.md)

## Supports

Works on Ubuntu 18.04 LTS and Ubuntu 20.04 LTS.

## IMPORTANT: Read before install

The script needs to be runned by root.

The script is based on this standard:

If you want to create a new web project for mydomain.com it will create:
* A database with name 'MYDOMAIN_STAGE' (the script will ask you the project stage). Ex: mydomain_prod
* A database user with name 'MYDOMAIN_user'. Ex: mydomain_user
* A directory for the project files named 'mydomain.com'.
* A nginx configuration for 'mydomain.com'.

So, the restore script only works if this nomenclature is respected.

## Installation

If git is not installed:

```bash
sudo apt-get update && sudo apt-get install git -y
```

Cloning repo:

```bash
git clone https://github.com/lpadula/brolit-shell
```

Change directories to the new ~/brolit-shell directory:

```bash
cd ~/brolit-shell
```

## Getting started

Give the execution permission to the script:

```bash
chmod +x runner.sh
```

Run it:

```bash
./runner.sh
```

The first time you run `runner.sh`, you'll be guided through a wizard in order to configure it. This configuration will be stored in `~/.brolit-shell.conf`.

## Update

Run updater.sh

```bash
./updater.sh
```

## Running as cron job

This script relies on a different configuration file for each system user. The default configuration file location is `root/.brolit-shell.conf`.
This means that if you setup the script with your user and then you try to run a cron job as root, it won't work.

* To setup the script to run as a cron job please use the option "CRON TASKS"

## Running tasks without menu

You can run some tasks like this:

```
./runner.sh --task "cloudflare-api" --subtask "clear_cache" --domain "broobe.com"
```

More information here: [FLAGS](./docs/DOC-flags.md)

## Third Party Utils

BROLIT Shell uses some third-party tools:

### Dropbox Uploader

Dropbox Uploader is a BASH script which can be used to upload, download, list or delete files from Dropbox, an online file sharing, synchronization and backup service.

### Google PageSpeed Insights API Tools

gitool.sh shell script to query Google PageSpeed Insights v4 & v5 API for site & origin metrics for FCP & DCL with additional support for GTMetrix & WebpageTest.org API tests

### Blacklist Checker

Blacklist check UNIX/Linux utility.

### Nench

VPS benchmark script — based on the popular bench.sh, plus CPU and ioping tests, and dual-stack IPv4 and v6 speedtests by default

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct, and the process for submitting pull requests to us.

## Code: Bash Best Practices

[Best Practices](./docs/CODE.md)

## Authors

* **Leandro Padula** - *Initial work* - [BROOBE](https://www.broobe.com)

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details