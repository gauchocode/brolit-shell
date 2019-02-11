# Broobe Utils Scripts

# LEMP Installation Scripts

# Backup Scripts

"Backup Scripts" is a **BASH** script which can be used to backup files and databases.
It's written in BASH scripting language and only needs **cURL**.

## Features

* File backups
* Database backups (MySQL or MariaDB)
* Cross platform
* Support for the official Dropbox API v2
* Simple step-by-step configuration wizard
* Simple and chunked file upload

## Getting started

Give the execution permission to the script and run it:

```bash
 $chmod +x runner.sh
```

The first time you run `runner.sh`, you'll be guided through a wizard in order to configure access to your Dropbox. This configuration will be stored in `~/.dropbox_uploader`.

## Running as cron job
Dropbox Uploader relies on a different configuration file for each system user. The default configuration file location is `$HOME/.dropbox_uploader`. This means that if you setup the script with your user and then you try to run a cron job as root, it won't work.
So, when running this script using cron, please keep in mind the following:
* Remember to setup the script with the user used to run the cron job
* Always specify the full script path when running it (e.g.  /path/to/dropbox_uploader.sh)

## BASH and Curl installation

**Debian & Ubuntu Linux:**
```bash
    sudo apt-get install bash (Probably BASH is already installed on your system)
    sudo apt-get install curl
```
