# BROLIT Shell

BROLIT Shell is a **BASH** based cloud server control software which can be used to quickly install a LEMP Stack on Ubuntu 18.04 and 20.04 servers, automate and restore backups, install PHP projects, and some usefull IT tasks.

![ScreenShot](./screenshot.png)

## Motivation

* Standarize servers configuration.
* Automatization of IT/DevOps tasks.
* Reduce time and errors on IT/DevOps tasks.

## Why Bash?

* Performance.
* Pre-installed on linux systems.
* Not overloaded with dependencies.

## Why BROLIT Shell?

* Backup and restore projects easily.
* Create, deploy and host php projects.
* Third party integrations: Dropbox, Cloudflare, Telegram, Netdata and more.
* WordPress support.
* Open-source.

## Features

* LEMP automated installer (Nginx, MySQL/MariaDB, PHP).
* Files and database backups (MySQL or MariaDB).
* Upload backups to Dropbox (API v2).
* Restore backups from Dropbox, URL or local files.
* WordPress automated installer.
* WP-CLI actions helper.
* Let's Encrypt actions helper.
* Cloudflare support (via API).
* PHP-FPM optimization tool (beta).
* Image optimization tools.
* UFW and Fail2ban support.
* Security Tools with malware scanners.
* IP/Domain blacklist checker.
* Benchmark tool.
* And more ...

## Supports

**Ubuntu LTS** 18.04 or 20.04

| Packages | Versions | BROLIT config |
| :------------- | :----------: | :----------: |
| **Nginx** | 1.18.x | `nginx.conf` + `mime.types` + server blocks |
| **Lets Encrypt** | 0.40.x | default config |
| **MySQL** | 8.0.x | `my.cnf` |
| **MariaDB** | 8.0.x | `my.cnf` |
| **PHP-FPM** | 7.4.x | `php.ini` + `php-fpm.conf` + `www.conf` |
| **Redis** | 5.0.x | `redis.conf` + `object-cache.php` |
| **WordPress** | 5.8.2 | default config |
| **WP-CLI** | 2.5.0 | default config |
| **Monit** | 5.26.x | `monitrc` + `mysql` + `phpfpm` + `nginx` + `redis` + `system` |
| **Netdata** | 1.32.x | `health_alarm_notify.conf` + custom `health.d` conf |
| **UFW Firewall** | 0.36 | default config |
| **Fail2Ban** | 0.11.x | default config |
| **ClamAV** | 0.103.x | `freshclam.conf` |
| **Lynis** | 2.6.x | default config |
| **Cockpit** | 0.102.x | default config |
| **Grafana** | SOON | default config |
| **Loki** | SOON | default config |
| **Teleport** | SOON | default config |

## Third Party Utils

BROLIT Shell uses some third-party tools:

### Dropbox Uploader

Dropbox Uploader is a BASH script which can be used to upload, download, list or delete files from Dropbox, an online file sharing, synchronization and backup service.

### Google PageSpeed Insights API Tools

gitool.sh shell script to query Google PageSpeed Insights v4 & v5 API for site & origin metrics for FCP & DCL with additional support for GTMetrix & WebpageTest.org API tests.

### Blacklist Checker

Blacklist check UNIX/Linux utility.

### Nench

VPS benchmark script — based on the popular bench.sh, plus CPU and ioping tests, and dual-stack IPv4 and v6 speedtests by default.

## IMPORTANT: Read before install

The script needs to be runned by root.

## Installation

### Cloud-init

```bash
#cloud-config
package_update: true
package_upgrade: true
packages:
 - git
runcmd:
- cd /root/
- git clone https://github.com/lpadula/brolit-shell
- chmod +x brolit-shell/runner.sh
```

### Manual

Cloning repo:

```bash
git clone https://github.com/lpadula/brolit-shell
```

Change directories to the new ~/brolit-shell directory:

```bash
cd ~/brolit-shell
```

Give the execution permission to the script:

```bash
chmod +x runner.sh
```

## Getting started

Execute BROLIT:

```bash
./runner.sh
```

The first time you run `runner.sh`, it will create the startup config file: `~/.brolit_conf.json`.
Open and edit this json file. 

You can find some example configurations here: 
* [.brolit_conf.json - lemp insecured](./docs/.brolit_conf-lemp_ins.json)
* [.brolit_conf.json - lemp secured](./docs/.brolit_conf-lemp_sec.json)
* [.brolit_conf.json - lemp custom](./docs/.brolit_conf-lemp_custom.json)

## Update

Run updater.sh

```bash
./updater.sh
```

## Running as cron job

This script relies on a different configuration file for each system user. The default configuration file location is `/root/.brolit_conf.json`.
This means that if you setup the script with your user and then you try to run a cron job as root, it won't work.

* To setup the script to run as a cron job please use the option "CRON TASKS"

## Running tasks without menu

You can run some tasks like this:

```
./runner.sh --task "cloudflare-api" --subtask "clear_cache" --domain "broobe.com"
```

More information here: [FLAGS](./docs/DOC-flags.md)

## TODO List
[TODO List](./docs/TODO.md)

## Changelog
[Changelog](./docs/CHANGELOG.md)

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct, and the process for submitting pull requests to us.

## Code: Bash Best Practices

[Best Practices](./docs/CODE.md)

## Team

This theme is maintained by the following person(s) and a bunch of [awesome contributors](https://github.com/lpadula/brolit-shell/graphs/contributors).

[![Leandro Padula](https://github.com/lpadula.png?size=100)](https://github.com/lpadula) |
--- |
[Leandro Padula](https://github.com/lpadula) |

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.