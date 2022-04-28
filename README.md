# BROLIT Shell

<!-- Table of Contents -->
## :notebook_with_decorative_cover: Table of Contents
- [About the Project](#star2-about-the-project)
  * [Motivation](#motivation)
  * [Why Bash?](#space_invader-why-bash)
  * [Features](#dart-features)
  * [Support](#warning-Supports)
- [Getting Started](#toolbox-getting-started)
  * [Prerequisites](#bangbang-prerequisites)
  * [Installation](#gear-installation)
  * [Run](#running-run)
  * [Deployment](#triangular_flag_on_post-deployment)
- [Roadmap](#compass-roadmap)
- [Contributing](#wave-contributing)
  * [Code of Conduct](#scroll-code-of-conduct)
- [FAQ](#grey_question-faq)
- [Team](#team)
- [License](#license)
- [Acknowledgements](#gem-acknowledgements)
## :star2: About the Project
BROLIT Shell is a **BASH** based cloud server control software which can be used to quickly install a LEMP Stack on Ubuntu 18.04, 20.04 and 22.04 servers, automate and restore backups, install PHP projects, and some usefull IT tasks.

![ScreenShot](./screenshot.png)

### Motivation
* Standarize servers configuration.
* Automatization of IT/DevOps tasks.
* Reduce time and errors on IT/DevOps tasks.

### :space_invader: Why Bash?
* Pre-installed on linux systems.
* Not overloaded with dependencies.

### :dart: Features
* Open-source.
* LEMP automated installer (Nginx, MySQL/MariaDB, PHP).
* Backup and restore projects easily.
* Upload backups to Dropbox (API v2) or FTP server.
* Restore backups from Dropbox, URL or local files.
* Create, deploy and host php projects.
* WordPress automated installer.
* WP-CLI actions helper.
* Let's Encrypt actions helper.
* Cloudflare support (via API).
* PHP-FPM optimization tool (beta).
* Image optimization tools.
* UFW and Fail2ban support.
* Security Tools with malware scanners.
* IP/Domain blacklist checker.
* Email and Telegram notifications.
* And more ...

### :warning: Supports

**Ubuntu LTS** 18.04, 20.04 or 22.04

| Packages | Versions | BROLIT config |
| :------------- | :----------: | :----------: |
| **Nginx** | O.S default | `nginx.conf` + `mime.types` + server blocks |
| **Lets Encrypt** | O.S default | default config |
| **MySQL** | O.S default | `my.cnf` |
| **MariaDB** | O.S default | `my.cnf` |
| **PHP-FPM** | 7.4.x/8.1.x | `php.ini` + `php-fpm.conf` + `www.conf` |
| **Redis** | O.S default | `redis.conf` + `object-cache.php` |
| **WordPress** | latest | default config |
| **WP-CLI** | 2.6.0 | default config |
| **Monit** | O.S default | `monitrc` + `mysql` + `phpfpm` + `nginx` + `redis` + `system` |
| **Netdata** | 1.32.x | `health_alarm_notify.conf` + custom `health.d` conf |
| **UFW Firewall** | O.S default | default config |
| **Fail2Ban** | O.S default | default config |
| **ClamAV** | O.S default | `freshclam.conf` |
| **Lynis** | 2.6.x | default config |
| **Cockpit** | 0.102.x | default config |
| **Portainer** | latest | dockerized (optional nginx proxy support) |
| **Grafana** | SOON | default config |
| **Teleport** | SOON | default config |

### Third Party Utils
BROLIT Shell uses some third-party tools:

#### Dropbox Uploader
Dropbox Uploader is a BASH script which can be used to upload, download, list or delete files from Dropbox, an online file sharing, synchronization and backup service.

#### Google PageSpeed Insights API Tools
gitool.sh shell script to query Google PageSpeed Insights v4 & v5 API for site & origin metrics for FCP & DCL with additional support for GTMetrix & WebpageTest.org API tests.

#### Blacklist Checker
Blacklist check UNIX/Linux utility.

#### Nench
VPS benchmark script — based on the popular bench.sh, plus CPU and ioping tests, and dual-stack IPv4 and v6 speedtests by default.

## :gear: Installation

### IMPORTANT: The script needs to be runned by root.
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

## :triangular_flag_on_post: First steps
Execute BROLIT:
```bash
./runner.sh
```

The first time you run BROLIT, it will prompt you to create a new config file: `~/.brolit_conf.json`. Then open and edit this json file.

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

## 🚨 Update
**BREAKING CHANGES SINCE VERSION 3.0**

Before upgrade:

1. Backup and rename the .brolit_conf.json
2. Run updater.sh
3. Run runner.sh to regenerate .brolit_conf.json
4. Edit .brolit_conf.json
5. If you use dropbox as backup system, please move old backups to another folder (new directory structure since version 3.2)
6. Run runner.sh

## :compass: TODO List
[TODO List](./docs/TODO.md)

## :wave: Contributing
Please read [CONTRIBUTING](./docs/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

[Best Practices](./docs/CODE.md)

## :busts_in_silhouette: Team
This theme is maintained by the following person(s) and a bunch of [awesome contributors](https://github.com/lpadula/brolit-shell/graphs/contributors).

[![Leandro Padula](https://github.com/lpadula.png?size=100)](https://github.com/lpadula) |
--- |
[Leandro Padula](https://github.com/lpadula) |

## :warning: License
This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.