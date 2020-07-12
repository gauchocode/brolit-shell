# TODO List

### In Progress

- [ ] New option to put a website offline. Maybe comment nginx server file, rename project_dir to domain-OFFLINE and restart nginx service

### Done ✓

- [x] Create TODO.md
- [x] Option to change hostname: https://www.cyberciti.biz/faq/ubuntu-20-04-lts-change-hostname-permanently/


## TODO

### For release 3.0-final

- [ ] When restore or create a new project and the db_user already exists, we need to ask what todo (new user or continue?)
- [ ] WordPress install fails when set a project name like: xyz_sub_domain (could be a problem with sed on wordpress installer)
- [ ] WP-CLI is required to the script works propperly, must install on script setup.
- [ ] On LEMP setup, afther basic installation must init plugin options wizard before ask to install aditional packages

### For release 3.1

- [ ] Auto-update script option.
- [ ] Refactor for restore from dropbox: 5 options (server_config, site_config, site, database and project)
- [ ] Check wp integrity files
- [ ] Complete refactor of "Options Wizard"
- [ ] Mailcow installer and backup
- [ ] Implements wpcli_rollback_plugin_version (on wpcli_helper.sh)
- [ ] Mail notifications after install a new project (with credentials info.)

### For release 3.2

- [ ] Refactor of RESTORE_FROM_SOURCE and complete server config restore
- [ ] Implement on restore_from_backup easy way to restore all sites
- [ ] Refactor of WORDPRESS_INSTALLER - COPY_FROM_PROJECT
        The idea is that you could create/delete/update different kind of projects (WP, Laravel, Standalone)
        Maybe add this for Laravel: https://gitlab.com/broobe/laravel-boilerplate/-/tree/master
        Important: if create a project with stage different than prod, block search engine indexation
- [ ] Better log with check_result and log_event functions (commons.sh)
- [ ] Complete refactor of delete_project script
- [ ] COPY_FROM_PROJECT option to exclude uploads directory: 
        rsync -ax --exclude [relative path to directory to exclude] /path/from /path/to
- [ ] An option to generate o regenerate a new nginx server configuration
- [ ] On php_installer if multiple php versions are installed de PHP_V need to be an array
        So, if you need to install a new site, must ask what php_v to use.
- [ ] Test VALIDATORS (commons.sh) and use functions on user prompt

### For release 3.4

- [ ] On backup failure, the email must show what files fails and what files are correct backuped
- [ ] Support for dailys, weeklys y monthlys backups
- [ ] Mail notification when a new site is installed
- [ ] Warning if script run on non default installation (no webserver or another than nginx)
- [ ] Option to install script on crontab (use cron_this function)
- [ ] Option to install Bashtop and other utils: http://packages.azlux.fr/

### For release 3.6

- [ ] Expand Duplicity support with a restore option
- [ ] Complete the pdf optimization process
- [ ] MySQL optimization script
- [ ] Rename database helper (with and without WP)
- [ ] Fallback for replace strings on wp database (if wp-cli fails, use old script version)
- [ ] Add others IT utils (change hostname, add floating IP, change SSH port)
        Ref: https://wiki.hetzner.de/index.php/Cloud_floating_IP_persistent/en
- [ ] Option to change php version on installed site. 
        See this implementation: https://easyengine.io/blog/easyengine-v4-0-15-released/
- [ ] Option to enable or disable OpCache

### For release 4.0

- [ ] Need a refactor to let the script be runned with flags
        Ex: ./runner.sh --backup-project="/var/www/some.domain.com"
- [ ] Support for Rclone? https://github.com/rclone/rclone
- [ ] Uptime Robot API?
- [ ] Telegram notifications support: https://adevnull.com/enviar-mensajes-a-telegram-con-bash/
- [ ] Better LEMP setup, tzdata y mysql_secure_installation without human intervention
- [ ] Add support to change dropbox to another storage service (Google Drive, SFTP, etc)
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
