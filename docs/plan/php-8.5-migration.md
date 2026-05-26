# PHP 8.5 Migration Plan

## Context

The project currently supports PHP 7.4 through 8.4 across two base image providers:

| PHP Version | Base Image | Status |
|---|---|---|
| 7.4 | `phpdockerio/php:7.4-fpm` | Deprecated |
| 8.0 | `phpdockerio/php:8.0-fpm` | Deprecated (no bcmath) |
| 8.1 | `phpdockerio/php:8.1-fpm` | Active |
| 8.2 | `serversideup/php:8.2-fpm` | Active |
| 8.3 | `serversideup/php:8.3-fpm` | Active |
| 8.4 | `serversideup/php:8.4-fpm` | Active |
| **8.5** | **`serversideup/php:8.5-fpm`** | **New** |

**Decision**: Keep `phpdockerio` for legacy versions (7.4-8.1) for backward compatibility. All **new versions (8.2+)** use `serversideup/php`.

## Extension Analysis

### Extensions provided by serversideup base image (no need to install)

These come pre-installed in the official PHP upstream or are added by serversideup:

**From official PHP:**
`ctype`, `curl`, `dom`, `fileinfo`, `filter`, `hash`, `mbstring`, `openssl`, `pcre`, `session`, `tokenizer`, `xml`

**From serversideup defaults:**
`opcache`, `pcntl`, `pdo_mysql`, `pdo_pgsql`, `redis`, `zip`

### Extensions requiring explicit installation

Comparison across all versions vs Laravel & WordPress requirements:

| Extension | phpdockerio 7.4 | 8.0 | 8.1 | serversideup 8.2-8.4 | Laravel req | WP req | Include in 8.5 |
|---|---|---|---|---|---|---|---|
| bcmath | yes | - | yes | yes | required | optional | **yes** |
| bz2 | yes | yes | yes | yes | - | - | **yes** |
| exif | - | - | - | yes | - | required | **yes** |
| gd | yes | yes | yes | yes | - | required | **yes** |
| imagick | yes | yes | yes | yes | - | recommended | **yes** |
| imap | yes | yes | yes | yes | - | optional | **yes** |
| intl | yes | yes | yes | yes | recommended | multisite | **yes** |
| mysqli | yes | yes | yes | yes | - | **required** | **yes** |
| soap | - | - | - | yes | - | optional | **yes** |
| xsl | - | - | - | yes | - | optional | **yes** |
| yaml | yes | - | yes | - | - | - | **yes** |

Total: **11 extensions** (13 in the current 8.4 template, but `pdo_mysql`, `redis`, `opcache`, `zip` are already in serversideup defaults — removed as redundant; `yaml` added back from phpdockerio).

### Extensions NOT included (and why)

| Extension | Present in phpdockerio | Reason for exclusion |
|---|---|---|
| `mcrypt` | 8.0, 8.1 | Removed from PHP 7.2+ |
| `xmlrpc` | 8.0, 8.1 | Removed from PHP 8.0+ |
| `cgi` | 8.1 | FPM is used, not CGI |
| `grpc` | 8.1 | Only needed for gRPC microservices |
| `http` | 8.1 | Depends on raphf, rarely needed |
| `inotify` | 8.1 | File watcher (dev tool only) |
| `oauth` | 8.0 | Laravel uses Socialite/Guzzle instead |
| `pgsql` | 8.0 | Only needed if using PostgreSQL |
| `raphf` | 8.0, 8.1 | Only needed as http extension dependency |
| `zstd` | 8.1 | Optional compression, rarely used |
| `xdebug` | 8.0 | Development only (not for production) |

## Changes vs Current 8.4 Template

| Change | File | Reason |
|---|---|---|
| **+ yaml** | Dockerfile | Was in phpdockerio 7.4/8.1, useful for YAML config files |
| **- pdo_mysql** | Dockerfile | Already included in serversideup base image |
| **- redis** | Dockerfile | Already included in serversideup base image |
| **- opcache** | Dockerfile | Already included in serversideup base image |
| **- zip** | Dockerfile | Already included in serversideup base image |
| **- libfreetype6-dev, libjpeg62-turbo-dev, libpng-dev, libzip-dev** | Dockerfile | `install-php-extensions` handles system dependencies automatically |

## Working Directory Change

Both stacks use `serversideup/php:fpm` images, but differ in WORKDIR:

- **PHP stack**: `WORKDIR "/application"` (mounted at `./application`)
- **WordPress stack**: `WORKDIR "/wordpress"` (mounted at `./wordpress`)

## Implementation Steps

### 1. Create `php-8.5_docker/` directories

**PHP stack** (7 files):
```
config/docker-compose/php/production-stack-proxy/php-8.5_docker/
├── nginx/nginx.conf              (same as 8.4)
├── php-fpm/Dockerfile            (serversideup/php:8.5-fpm, 11 extensions)
├── php-fpm/php-ini-overrides.ini (same as 8.4)
├── php-fpm/opcache-prod.ini      (same as 8.4)
├── php-fpm/php-fpm-pool-prod.conf(same as 8.4)
├── README.md                     (same as 8.4)
└── README.html                   (same as 8.4)
```

**WordPress stack** (7 files):
```
config/docker-compose/wordpress/production-stack-proxy/php-8.5_docker/
├── nginx/nginx.conf              (same as 8.4)
├── php-fpm/Dockerfile            (serversideup/php:8.5-fpm, WORKDIR /wordpress)
├── php-fpm/php-ini-overrides.ini (same as 8.4)
├── php-fpm/opcache-prod.ini      (same as 8.4)
├── php-fpm/php-fpm-pool-prod.conf(same as 8.4)
├── README.md                     (same as 8.4)
└── README.html                   (same as 8.4)
```

### 2. Update `libs/apps/docker_helper.sh` (line 2122)

```bash
# Before:
php_versions="8.0 8.1 8.2 8.3 8.4"

# After:
php_versions="8.0 8.1 8.2 8.3 8.4 8.5"
```

### 3. Docker Update Flow

When `docker_update_php_version` is called:

1. Read `PHP_VERSION` from `.env`
2. Show version selection menu (now includes `8.5`)
3. Copy template directory `php-8.5_docker/` from config templates to project (if not exists)
4. Update `PHP_VERSION=8.5` in `.env`
5. Run `docker compose pull` + `docker compose up --detach --build`
6. Verify containers are running

### 4. Migration Risk: phpdockerio → serversideup

When upgrading from 8.1 (phpdockerio) to 8.2+ (serversideup), the Dockerfile changes completely:

| Aspect | phpdockerio (≤8.1) | serversideup (≥8.2) |
|---|---|---|
| Base image | Ubuntu + Ondřej Surý PPA | Official PHP |
| Extension install | `apt-get install phpX.X-*` | `install-php-extensions` |
| Runtime user | root | www-data (unprivileged) |
| PHP config path | `/etc/php/X.X/fpm/conf.d/` | Same path ✓ |

The script handles this correctly because:
- It copies the entire `php-X.X_docker` directory from the template (creates fresh if not exists)
- The docker-compose.yml uses `PHP_VERSION` variable dynamically
- `docker compose up --build` rebuilds from the new Dockerfile

**Warning**: Custom Dockerfile modifications (extra extensions, custom packages) from the old version are NOT carried over. Users must manually re-add them after migration.
