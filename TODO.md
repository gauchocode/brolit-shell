# TODO List

## For release 3.0.1

### TODO

- [ ] IMPORTANT! When restore a backup and change project_name or/and project_domain the script fails:
        To create a propper nginx congiguration
        To replace wp-config.php parameters
        To change cloudflare config
        Need to re-run let's encrypt
        Need to run "search and replace" script from wp-cli
- [ ] Notifications: Email HTML breaks sometimes.
- [ ] Backups: make_project_backup is broken, need a refactor asap!
- [ ] Nginx: put_project_offline need another aproach. Maybe put an index.html with message.
- [ ] Secure store for MySQL password: https://www.dokry.com/27126

### In Progress

- [ ] Better code documentation.
- [ ] Complete refactor on delete_project script.
- [ ] Notifications: Subject status dont't change on error or warning.
- [ ] Log/Display: better log handling and display improvements.

### Need more testing
- [ ] WordPress: Install fails when set a project name like: xyz_sub_domain.
- [ ] Backups: When restore or create a new project and the db_user already exists, we need to ask what todo (new user or continue?).
- [ ] Installers: On LEMP setup, after basic installation must init plugin options wizard before ask to install aditional packages.
- [ ] Nginx: New default nginx configuration for wordpress projects.

### Done ✓

- [x] IT: Option to change SSH port.
- [x] IT: Option to change hostname.
- [x] IT: Option to config a floating IP.
- [x] IT: Option to install script on crontab.
- [x] WordPress: WP-CLI is required to the script works propperly, must install on script setup.
- [x] Nginx: New option to put a website offline/online.
- [x] Better log with log_event functions.
- [x] Refactor for better dependencies management, and cleaner code in runner.sh
- [x] Notifications: Telegram notifications support.

## For release 3.1
- [ ] Warning if script run on non default installation (no webserver or another than nginx).
- [ ] Finish function: download_and_restore_config_files_from_dropbox
- [ ] Complete refactor of "Options Wizard": (Backup Options, Notification Options, Cloudflare Config).
- [ ] Nginx: Add http2 support on nginx server config files.
- [ ] Nginx: New option to put website on maintenance.
- [ ] LetsEncrypt: Need a better way to re-install a certificate after a website migration.
- [ ] Scheduled options: backups, malware scans, image optimizations and wp actions (core and plugins updates, checksum and wp re-installation)
- [ ] Backups: Support for dailys, weeklys y monthlys backups.
- [ ] Notifications: malware scans and others scheduled options.
- [ ] Backups: Refactor for backup/restore: 5 options (server_config, site_config, site, database and project).
- [ ] Auto-update script option.
- [ ] Solve small "TODOs" comments on the project.
- [ ] PHP: php_reconfigure refactor (replace strings instead of replace entired config files)
- [ ] Scheduled options: Add option to run on specific time.
- [ ] SFTP: Support sftp_add_user
- [ ] Add a method to auto-load scripts from /utils

## For release 3.2

- [ ] Utils: Support for phpservermon: https://github.com/phpservermon/phpservermon
- [ ] Nginx: Option to copy or generate a new nginx server configuration.
- [ ] Nginx: Globals configs support.
- [ ] Installers: Mailcow installer and backup.
- [ ] Installers: Netdata only reports CRITICAL message, (CLEAR are not reported).
- [ ] Installers: Option to select netdata metrics to be reported.
- [ ] Notifications: After install a new project (with credentials info).
- [ ] Backups: On backup failure, the email must show what files fails and what files are correct backuped.
- [ ] Backups: Implement on restore_from_backup easy way to restore all sites.
- [ ] Refactor of RESTORE_FROM_SOURCE and complete server config restore.
- [ ] Wordpress: Better wp-cli support 
 - [ ] Rollback plugins and core updates (wpcli_rollback_plugin_version on wpcli_helper.sh)
 - [ ] Buddypress support: https://github.com/buddypress/wp-cli-buddypress

## For release 3.3

- [ ] Wordpress: When restore or create a project on PROD state, ask if want to run "wpcli_run_startup_script"
- [ ] PHP: Option to enable or disable OpCache
- [ ] Installers: Refactor of WORDPRESS_INSTALLER - COPY_FROM_PROJECT
        The idea is that you could create/copy/delete/update different kind of projects (WP, Laravel, React, Composer, Empty)
        Maybe add this for Laravel: https://gitlab.com/broobe/laravel-boilerplate/-/tree/master
        Important: if create a project with stage different than prod, block search engine indexation
- [ ] Installers: COPY_FROM_PROJECT option to exclude uploads directory
        rsync -ax --exclude [relative path to directory to exclude] /path/from /path/to
- [ ] Installers: On php_installer if multiple php versions are installed de PHP_V need to be an array.
        So, if you need to install a new site, must ask what php_v to use.
- [ ] Installers: Option to install Bashtop and other utils: http://packages.azlux.fr/

## For release 3.4

- [ ] Backups: Directory Blacklist with whiptail (for backup configuration).
- [ ] Server Optimization: Complete the pdf optimization process.
- [ ] MySQL: Optimization script.
- [ ] MySQL: Rename database helper (with and without WP).
- [ ] WordPress: Fallback for replace strings on wp database (if wp-cli fails, use old script version).
- [ ] WordPress: WP Network support (nginx config, and wp-cli commands).
- [ ] Nginx: Multidomain support for nginx.
- [ ] IT Utils: Control of mounted partitions or directories.
- [ ] IT Utils: Better malware detection with https://github.com/rfxn/linux-malware-detect

## For release 3.5

- [ ] Backups: Expand Duplicity support with a restore option.
- [ ] Backups: Rsync support on mounted device or with SSH config.
- [ ] PHP: Option to change php version on installed site.
        https://easyengine.io/blog/easyengine-v4-0-15-released/
- [ ] Notifications: Discord support
        https://docs.netdata.cloud/health/notifications/discord/
- [ ] Security: Option to auto-install security updates on Ubuntu: 
        https://help.ubuntu.com/lts/serverguide/automatic-updates.html
- [ ] Nginx: bad bot blocker.
        https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker

## For release 4.0

- [ ] Refactor to let the script be runned with flags
        Ex: ./runner.sh --backup-project="/var/www/some.domain.com"
- [ ] Support for Rclone? https://github.com/rclone/rclone
- [ ] Better LEMP setup, tzdata y mysql_secure_installation without human intervention
- [ ] User authentication support with roles (admin, backup-only, project-creation-only)
- [ ] Add support to change dropbox to another storage service (Google Drive, SFTP, etc)
        Ref. Google Drive script: https://github.com/labbots/google-drive-upload
- [ ] Hetzner cloud cli support. Refs:
        https://github.com/hetznercloud/cli
        https://github.com/thabbs/hetzner-cloud-cli-sh
        https://github.com/thlisym/hetznercloud-py
        https://hcloud-python.readthedocs.io/en/latest/
- [ ] Web GUI, some options:
        https://github.com/bugy/script-server
        https://github.com/joewalnes/websocketd
        https://github.com/ncarlier/webhookd
        https://www.php.net/manual/en/function.shell-exec.php
