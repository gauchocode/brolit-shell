# BROLIT-SHELL

## :star2: About the project
BROLIT-SHELL is a server management tool built on **BASH**, designed to expediently set up a LEMP Stack on Ubuntu servers (versions 20.04, and 22.04). It streamlines the process of automating and restoring backups, deploying PHP projects, and executing various essential IT tasks efficiently.

![ScreenShot](./screenshot.png)

### :space_invader: Why Bash?
* Natively pre-installed on Linux systems.
* Lightweight with minimal dependencies.

### :bulb: Benefits
* Standardize server configurations.
* Automate IT/DevOps tasks for efficiency.
* Minimize time spent and errors in IT/DevOps operations.

### :dart: Features
* Fully open-source.
* Automated LEMP stack installation (Nginx, MySQL/MariaDB, PHP).
* Simplified backup and restoration processes.
* Backup upload functionality to Dropbox or an FTP server.
* Restore backups from Dropbox, URLs, or local files.
* Streamlined creation, deployment, and hosting of PHP projects.
* WordPress automated installation feature.
* WP-CLI actions helper for WordPress management.
* Integration of Let's Encrypt for SSL/TLS management.
* Cloudflare support through API integration.
* Image optimization tools to enhance web performance.
* Comprehensive security tools, including malware scanners.
* IP/Domain blacklist checking tool.
* Email and Telegram notifications for system alerts.
* Additional features and tools for enhanced server management.

### :dart: New features! (since v 3.3.9)
* Enhanced Docker Integration:
  * Facilitates backing up, restoring, and deploying new projects within Docker containers.
  * Offers WordPress-cli support specifically tailored for Docker environments.
* Wordfence-cli scanning capabilities for WordPress sites.

### :warning: Supports

**Ubuntu LTS** 20.04 or 22.04

| Packages | Versions | BROLIT config |
| :------------- | :----------: | :----------: |
| **Nginx** | O.S default | `nginx.conf` + `mime.types` + server blocks |
| **Lets Encrypt** | O.S default | default config |
| **MySQL** | O.S default | `my.cnf` |
| **MariaDB** | O.S default | `my.cnf` |
| **PHP-FPM** | 7.4.x/8.2.x | `php.ini` + `php-fpm.conf` + `www.conf` |
| **Redis** | O.S default | `redis.conf` + `object-cache.php` |
| **Monit** | O.S default | `monitrc` + `mysql` + `phpfpm` + `nginx` + `redis` + `system` |
| **WordPress** | latest | default config |
| **WP-CLI** | latest | default config |
| **Docker** | latest | default config |

### Enhanced installation support for leading tools
Experience streamlined setup for a range of exceptional tools including Netdata, Grafana, Loki, Promtail, Portainer, Portainer Agent, Cockpit, Zabbix, and more.

### Third party utils
BROLIT Shell uses some third-party tools:

#### Dropbox Uploader
Dropbox Uploader is a BASH script which can be used to upload, download, list or delete files from Dropbox, an online file sharing, synchronization and backup service.

#### Wordfence-cli
Wordfence-cli is a widely-used security tool for WordPress that provides features like malware scanning, and security monitoring.

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
- git clone https://github.com/gauchocode/brolit-shell
- chmod +x brolit-shell/runner.sh
```

### Manual
Cloning repo:
```bash
git clone https://github.com/gauchocode/brolit-shell
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
./runner.sh --task "cloudflare-api" --subtask "clear_cache" --domain "gauchocode.com"
```

More information here: [FLAGS](./docs/DOC-flags.md)

## 🚨 Update
**BREAKING CHANGES SINCE VERSION 3.2**

Before upgrade:

1. Backup and rename the .brolit_conf.json
2. Run updater.sh
3. Run runner.sh to regenerate .brolit_conf.json
4. Edit .brolit_conf.json
5. If you use Dropbox as backup system, please move old backups to another folder (new directory structure since version 3.2)
6. Run runner.sh

## :compass: TODO List
[TODO List](./docs/TODO.md)

## :wave: Contributing
Please read [CONTRIBUTING](./docs/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

[Best Practices](./docs/CODE.md)

## :busts_in_silhouette: Team
This theme is maintained by the following person(s) and a bunch of [awesome contributors](https://github.com/gauchocode/brolit-shell/graphs/contributors).

[![Leandro Padula](https://github.com/lpadula.png?size=100)](https://github.com/lpadula) |
--- |
[Leandro Padula](https://github.com/lpadula) |

## :warning: License
This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.