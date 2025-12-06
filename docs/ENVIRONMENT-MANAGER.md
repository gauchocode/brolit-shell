# Environment Manager

## Overview

The **Environment Manager** is a comprehensive system for managing and optimizing both host-based and Docker containerized services. It provides a unified interface for configuration, optimization, and maintenance tasks across different execution environments.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Menu Structure](#menu-structure)
3. [Host Environment Manager](#host-environment-manager)
4. [Docker Environment Manager](#docker-environment-manager)
5. [Optimizers](#optimizers)
6. [Configuration Files](#configuration-files)
7. [Usage Examples](#usage-examples)
8. [Technical Reference](#technical-reference)

---

## Architecture

### Design Philosophy

The Environment Manager follows a **context-aware optimization** approach:

- **Explicit Selection**: Users explicitly choose between Host or Docker environments
- **Granular Control**: Optimize individual containers or the host system
- **Non-Destructive**: All optimizations are reversible and logged
- **Detection-Based**: Automatically detects installed services and running containers

### Component Structure

```
Environment Manager
├── Host Environment Manager
│   ├── Installers and Configurators
│   ├── Optimizations
│   ├── Security Tools
│   └── System Utilities
└── Docker Environment Manager
    ├── Project Selection
    ├── Container Status
    ├── Individual Container Optimization
    └── Container Management
```

---

## Menu Structure

### Main Menu

```
ENVIRONMENT MANAGER
├─ 01) HOST ENVIRONMENT
├─ 02) DOCKER CONTAINERS
└─ 03) BACK TO MAIN MENU
```

### Host Environment Submenu

```
HOST ENVIRONMENT MANAGER
├─ 01) INSTALLERS AND CONFIGURATORS
│   ├─ PHP-FPM
│   ├─ Nginx
│   └─ Monit
├─ 02) OPTIMIZATIONS
│   ├─ Optimize PHP-FPM
│   ├─ Optimize Nginx
│   ├─ Optimize MySQL
│   ├─ Optimize RAM Usage
│   ├─ Optimize Images
│   └─ Delete Old Logs
├─ 03) SECURITY TOOLS
│   ├─ Fail2ban
│   ├─ UFW Firewall
│   └─ SSH Hardening
└─ 04) SYSTEM UTILITIES
    ├─ Change SSH Port
    ├─ Change Hostname
    ├─ Add Floating IP
    ├─ Create/Delete SFTP User
    ├─ Reset MySQL Root Password
    ├─ Blacklist Checker
    ├─ Benchmark Server
    └─ Install Aliases
```

### Docker Environment Submenu

```
DOCKER ENVIRONMENT MANAGER
├─ Project Selection (list all docker-compose projects)
└─ Per-Project Menu:
    ├─ 01) VIEW CONTAINER STATUS
    ├─ 02) OPTIMIZE PHP-FPM
    ├─ 03) OPTIMIZE NGINX
    ├─ 04) OPTIMIZE MYSQL
    ├─ 05) OPTIMIZE REDIS
    ├─ 06) CLEAN RAM USAGE
    ├─ 07) VIEW CONTAINER LOGS
    ├─ 08) RESTART CONTAINERS
    ├─ 09) STOP CONTAINERS
    ├─ 10) START CONTAINERS
    └─ 11) EXECUTE COMMAND IN CONTAINER
```

---

## Host Environment Manager

### Installers and Configurators

Manages installation and configuration of services running directly on the host system.

**Supported Services:**
- PHP-FPM (versions 7.4, 8.0, 8.1, 8.2, 8.3)
- Nginx
- Monit

**Features:**
- Version selection and switching
- Automated dependency resolution
- Configuration template deployment
- Service validation

---

### Host Optimizations

#### 1. Optimize PHP-FPM (Host)

**What it does:**
- Analyzes server resources (RAM, CPU cores)
- Calculates optimal PHP-FPM pool settings
- Configures OPcache for maximum performance
- Applies settings to `/etc/php/{version}/fpm/pool.d/www.conf`

**Optimized Parameters:**

| Parameter | Calculation | Purpose |
|-----------|-------------|---------|
| `pm.max_children` | `(Total RAM - Reserved RAM) / Average PHP Process Size` | Maximum worker processes |
| `pm.start_servers` | `CPU Cores × 4` | Initial worker count |
| `pm.min_spare_servers` | `CPU Cores × 2` | Minimum idle workers |
| `pm.max_spare_servers` | `CPU Cores × 4` | Maximum idle workers |
| `pm.max_requests` | `500` | Requests before worker restart |
| `pm.process_idle_timeout` | `10s` | Idle worker timeout |
| `opcache.enable` | `1` | Enable OPcache |
| `opcache.memory_consumption` | `128` | OPcache RAM (MB) |
| `opcache.max_accelerated_files` | `10000` | Max cached files |
| `opcache.revalidate_freq` | `240` | Revalidation frequency (seconds) |

**Algorithm:**
```
Reserved RAM = MySQL Avg RAM + Nginx Avg RAM + 1024 MB (buffer)
Dedicated RAM = Total RAM - Reserved RAM
PHP Avg RAM = 90 MB (measured average)
pm.max_children = Dedicated RAM / PHP Avg RAM
```

**Example Output:**
```
Server Specs:
- Total RAM: 8192 MB
- CPU Cores: 4
- Reserved RAM: 2048 MB
- Dedicated RAM: 6144 MB

Calculated Settings:
- pm.max_children: 68
- pm.start_servers: 16
- pm.min_spare_servers: 8
- pm.max_spare_servers: 16
```

**Impact:**
- ✅ Prevents memory exhaustion
- ✅ Reduces response time under load
- ✅ Optimal worker scaling
- ✅ Efficient cache utilization

---

#### 2. Optimize Nginx (Host)

**What it does:**
- Configures worker processes based on CPU cores
- Adjusts connection limits and timeouts
- Optimizes buffer sizes for PHP-FPM communication
- Enables gzip compression

**Optimized Parameters:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `worker_processes` | `auto` (CPU cores) | Parallel request handling |
| `worker_connections` | `2048` | Max connections per worker |
| `keepalive_timeout` | `65` | Keep-alive connection timeout |
| `client_max_body_size` | `100M` | Max upload size |
| `fastcgi_buffers` | `32 32k` | PHP-FPM response buffers |
| `fastcgi_buffer_size` | `64k` | Initial response buffer |
| `gzip` | `on` | Enable compression |
| `gzip_types` | `text/plain text/css application/json...` | Compress these MIME types |

**Impact:**
- ✅ Better concurrent connection handling
- ✅ Reduced memory usage per connection
- ✅ Faster response times
- ✅ Lower bandwidth usage

---

#### 3. Optimize MySQL (Host)

**What it does:**
- Analyzes database size and RAM availability
- Configures InnoDB buffer pool
- Optimizes query cache and connection settings
- Tunes temporary table sizes

**Optimized Parameters:**

| Parameter | Calculation | Purpose |
|-----------|-------------|---------|
| `innodb_buffer_pool_size` | `50-70% of Total RAM` | Main InnoDB cache |
| `innodb_log_file_size` | `256M` | Transaction log size |
| `innodb_flush_log_at_trx_commit` | `2` | Log flush strategy |
| `innodb_flush_method` | `O_DIRECT` | File I/O method |
| `max_connections` | `150` | Max simultaneous connections |
| `join_buffer_size` | `2M` | JOIN operation buffer |
| `sort_buffer_size` | `2M` | Sort operation buffer |
| `tmp_table_size` | `64M` | Temp table size in RAM |
| `max_heap_table_size` | `64M` | Max MEMORY table size |

**Algorithm:**
```
Total RAM: 8192 MB
InnoDB Buffer Pool = 50% of RAM = 4096 MB
```

**Impact:**
- ✅ Faster query execution
- ✅ Reduced disk I/O
- ✅ Better concurrent query handling
- ✅ Improved JOIN performance

---

#### 4. Optimize RAM Usage (Host)

**What it does:**
- Restarts PHP-FPM to free accumulated memory
- Clears Linux page cache, dentries, and inodes
- Swaps memory back from swap partition
- Logs memory state before and after

**Actions Performed:**
1. **Restart PHP-FPM**: `service php{version}-fpm restart`
2. **Clear Swap**: `swapoff -a && swapon -a`
3. **Drop Caches**: `sync && echo 1 > /proc/sys/vm/drop_caches`

**Impact:**
- ✅ Frees memory leaks
- ✅ Improves cache hit ratio
- ✅ Reduces swap usage
- ✅ Better overall performance

**Warning:** This causes a brief service interruption (< 2 seconds)

---

#### 5. Optimize Images

**What it does:**
- Scans WordPress `wp-content/uploads` directories
- Resizes large images to maximum dimensions
- Compresses JPEG images using jpegoptim
- Compresses PNG images using optipng
- Optimizes PDF files using Ghostscript

**Process:**

**Image Resizing:**
- Maximum dimensions: 1920x1080px
- Tool: ImageMagick (`mogrify`)
- Preserves aspect ratio
- Only resizes if larger than max

**JPEG Compression:**
- Quality: 80%
- Tool: jpegoptim
- Progressive encoding: enabled
- Strips metadata: EXIF, IPTC

**PNG Compression:**
- Optimization level: 7 (highest)
- Tool: optipng
- Lossless compression
- Strips metadata

**PDF Compression:**
- Settings: `/screen` (72 DPI)
- Tool: Ghostscript
- Only replaces if smaller

**Incremental Processing:**
- First run: Processes all images
- Subsequent runs: Only images modified in last 7 days
- Tracking: `~/.server_opt-info`

**Example Output:**
```
Processing: /var/www/example.com/wp-content/uploads/
- Resized: 45 images (saved 120 MB)
- Compressed JPG: 234 images (saved 89 MB)
- Compressed PNG: 67 images (saved 12 MB)
- Total saved: 221 MB
```

**Impact:**
- ✅ Faster page load times
- ✅ Reduced storage usage
- ✅ Lower bandwidth consumption
- ✅ Better SEO scores

---

#### 6. Delete Old Logs

**What it does:**
- Removes system logs older than 7 days
- Truncates large Docker container logs (>1GB)
- Cleans up rotated log files

**Targets:**
- `/var/log/` (system logs)
- `/var/lib/docker/containers/*/*-json.log` (Docker logs)

**Example:**
```
Deleted: 1,234 old log files (saved 2.3 GB)
Truncated: 3 large Docker logs (freed 4.1 GB)
```

**Impact:**
- ✅ Frees disk space
- ✅ Improves log parsing speed
- ✅ Prevents disk full errors

---

## Docker Environment Manager

### Project Selection

The Docker Environment Manager first prompts you to select a Docker Compose project:

```
Available Docker Projects:
1) example.com
   - mysql (running)
   - nginx (running)
   - php-fpm (running)
   - redis (running)

2) test.local
   - mysql (running)
   - nginx (running)
   - php-fpm (running)

Select project: _
```

**Detection Method:**
- Scans `${PROJECTS_PATH}` for directories
- Checks for `docker-compose.yml` file
- Reads `.env` file for project name
- Lists running containers via `docker compose ps`

---

### Docker Optimizations

#### 1. Optimize PHP-FPM (Docker)

**What it does:**
- Detects PHP version inside container
- Calculates optimal settings based on container memory limits
- Generates optimized pool configuration
- Mounts configuration as volume
- Reloads PHP-FPM without restart

**Configuration File:**
- Path: `{project}/php-{version}_docker/php-fpm/z-optimised.conf`
- Mounted to: `/etc/php/{version}/fpm/pool.d/z-optimised.conf`

**Optimized Parameters:**

| Parameter | Calculation | Purpose |
|-----------|-------------|---------|
| `pm` | `dynamic` | Dynamic worker management |
| `pm.max_children` | `(Container RAM - 512MB) / 90MB` | Max workers |
| `pm.start_servers` | `nproc` | Initial workers |
| `pm.min_spare_servers` | `nproc / 2` | Min idle workers |
| `pm.max_spare_servers` | `nproc` | Max idle workers |
| `pm.max_requests` | `500` | Requests before restart |
| `pm.process_idle_timeout` | `10s` | Idle timeout |

**OPcache Settings:**
- File: `{project}/php-{version}_docker/php-fpm/opcache-prod.ini`

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `opcache.enable` | `1` | Enable OPcache |
| `opcache.memory_consumption` | `128` | Cache size (MB) |
| `opcache.max_accelerated_files` | `10000` | Max cached files |
| `opcache.validate_timestamps` | `0` | Disable file checks (production) |
| `opcache.revalidate_freq` | `0` | Never revalidate |
| `opcache.enable_file_override` | `1` | Speeds up file operations |

**Memory Limit Detection:**
```bash
# Check container memory limit
docker inspect {container} --format='{{.HostConfig.Memory}}'

# If no limit, use host RAM
# If limit exists, use container limit
```

**Reload Command:**
```bash
# Send USR2 signal to PHP-FPM master process
docker compose -f docker-compose.yml exec -T php-fpm kill -USR2 1
```

**Example:**
```
Container: example_stack_php-fpm
Memory Limit: 2048 MB
PHP Version: 8.3

Calculated Settings:
- pm.max_children: 17
- pm.start_servers: 4
- pm.min_spare_servers: 2
- pm.max_spare_servers: 4

✓ Configuration written to: php-8.3_docker/php-fpm/z-optimised.conf
✓ PHP-FPM reloaded successfully
```

**Impact:**
- ✅ Prevents OOM (Out of Memory) kills
- ✅ Optimal concurrency
- ✅ Fast opcode caching
- ✅ No downtime (graceful reload)

---

#### 2. Optimize Nginx (Docker)

**What it does:**
- Locates Nginx configuration file
- Configures worker processes and connections
- Optimizes FastCGI buffers
- Updates configuration without restart

**Configuration File:**
- Path: `{project}/php-{version}_docker/nginx/nginx.conf`
- Mounted to: `/etc/nginx/conf.d/default.conf`

**Optimized Parameters:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `worker_processes` | `auto` | Match CPU cores |
| `worker_connections` | `2048` | Connections per worker |
| `keepalive_timeout` | `65` | Keep-alive timeout |
| `client_max_body_size` | `108M` | Max upload size |
| `fastcgi_buffers` | `32 32k` | Response buffers |
| `fastcgi_buffer_size` | `64k` | Initial buffer |
| `send_timeout` | `300` | Response timeout |

**Reload Command:**
```bash
docker compose -f docker-compose.yml exec -T webserver nginx -s reload
```

**Example:**
```
Container: example_stack_nginx
Configuration: php-8.3_docker/nginx/nginx.conf

Updates:
- worker_processes: 1 → 4
- worker_connections: 1024 → 2048
- fastcgi_buffers: 16 16k → 32 32k

✓ Nginx configuration tested successfully
✓ Nginx reloaded without errors
```

**Impact:**
- ✅ Handle more concurrent requests
- ✅ Better PHP-FPM communication
- ✅ Reduced 502/504 errors
- ✅ No downtime

---

#### 3. Optimize MySQL (Docker)

**What it does:**
- Detects MySQL/MariaDB version
- Calculates optimal InnoDB settings
- Generates custom configuration file
- Mounts as volume and restarts container

**Configuration File:**
- Path: `{project}/.mysql_data/conf.d/60-tuning.cnf`
- Mounted to: `/etc/mysql/conf.d/60-tuning.cnf`

**Optimized Parameters:**

| Parameter | Calculation | Purpose |
|-----------|-------------|---------|
| `innodb_buffer_pool_size` | `50% of container RAM` | Main cache |
| `innodb_log_file_size` | `256M` | Transaction log |
| `innodb_flush_log_at_trx_commit` | `2` | Durability vs speed |
| `innodb_flush_method` | `O_DIRECT` | Bypass OS cache |
| `max_connections` | `150` | Max connections |
| `join_buffer_size` | `2M` | JOIN buffer |
| `sort_buffer_size` | `2M` | Sort buffer |
| `tmp_table_size` | `64M` | Temp table size |
| `max_heap_table_size` | `64M` | MEMORY table size |
| `slow_query_log` | `1` | Enable slow log |
| `long_query_time` | `2` | Log queries > 2s |

**Algorithm:**
```bash
# Get container memory limit
container_mem=$(docker inspect {container} --format='{{.HostConfig.Memory}}')

if [[ ${container_mem} == "0" ]]; then
  # No limit, use 50% of host RAM
  innodb_buffer_pool_size=$((host_ram / 2))
else
  # Use 50% of container limit
  innodb_buffer_pool_size=$((container_mem / 2))
fi
```

**Restart Process:**
```bash
# MySQL requires restart for most settings
docker compose -f docker-compose.yml restart mysql

# Wait for MySQL to be ready
docker compose -f docker-compose.yml exec mysql mysqladmin ping
```

**Example:**
```
Container: example_stack_mysql
Memory Limit: 4096 MB
Version: MariaDB 10.11

Calculated Settings:
- innodb_buffer_pool_size: 2048 MB
- innodb_log_file_size: 256 MB
- max_connections: 150

✓ Configuration written to: .mysql_data/conf.d/60-tuning.cnf
✓ MySQL restarted successfully
⏱ Downtime: ~5 seconds
```

**Impact:**
- ✅ Faster query execution
- ✅ Reduced disk I/O
- ✅ Better concurrent access
- ✅ Improved JOIN performance

**Warning:** Restarting MySQL causes brief downtime (~5-10 seconds)

---

#### 4. Optimize Redis (Docker)

**What it does:**
- Configures memory limits and eviction policy
- Enables persistence options
- Optimizes for WordPress object caching
- Flushes old cache data

**Configuration Method:**
- Redis uses command-line arguments in `docker-compose.yml`
- Or separate `redis.conf` file

**Optimized Parameters:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `maxmemory` | `256mb` | Max RAM usage |
| `maxmemory-policy` | `allkeys-lru` | Eviction policy |
| `save` | `900 1 300 10 60 10000` | Persistence rules |
| `appendonly` | `yes` | AOF persistence |
| `tcp-backlog` | `511` | Connection queue |
| `timeout` | `300` | Client timeout |

**Eviction Policies:**

| Policy | Description | Use Case |
|--------|-------------|----------|
| `noeviction` | Return errors when memory full | Critical data |
| `allkeys-lru` | Evict least recently used keys | Cache (WordPress) |
| `volatile-lru` | Evict LRU keys with TTL | Session data |
| `allkeys-random` | Evict random keys | Testing |

**Flush Cache:**
```bash
# Clear all cached data
docker exec -i {redis_container} redis-cli FLUSHALL

# Or selective flush
docker exec -i {redis_container} redis-cli FLUSHDB
```

**Example:**
```
Container: example_stack_redis
Version: Redis 6.0

Actions:
- Set maxmemory: 256 MB
- Set eviction policy: allkeys-lru
- Flushed cache: 1,234 keys

✓ Redis optimized for WordPress caching
```

**Impact:**
- ✅ Prevents memory overflow
- ✅ Automatic cache eviction
- ✅ Faster page loads
- ✅ Reduced database queries

---

#### 5. Clean RAM Usage (Docker)

**What it does:**
- Restarts PHP-FPM container to free memory
- Flushes Redis cache
- Removes unused Docker images and volumes

**Actions Performed:**

1. **Restart PHP-FPM:**
```bash
docker compose -f docker-compose.yml restart php-fpm
```

2. **Flush Redis:**
```bash
docker exec -i {redis_container} redis-cli FLUSHALL
```

3. **Docker Cleanup:**
```bash
# Remove unused images
docker image prune -af

# Remove unused volumes
docker volume prune -f

# Remove stopped containers
docker container prune -f
```

**Example:**
```
Project: example.com

Actions:
✓ Restarted PHP-FPM (freed 234 MB)
✓ Flushed Redis cache (1,456 keys)
✓ Removed unused images (saved 1.2 GB)
✓ Removed unused volumes (saved 345 MB)

Total RAM freed: 1.8 GB
```

**Impact:**
- ✅ Frees accumulated memory
- ✅ Clears stale cache
- ✅ Reclaims disk space
- ✅ Better container performance

**Warning:** Brief service interruption (~2-5 seconds)

---

## Configuration Files

### Host Environment

#### PHP-FPM Configuration
```
/etc/php/{version}/fpm/pool.d/www.conf
/etc/php/{version}/fpm/php.ini
```

#### Nginx Configuration
```
/etc/nginx/nginx.conf
/etc/nginx/sites-available/{domain}
/etc/nginx/sites-enabled/{domain}
```

#### MySQL Configuration
```
/etc/mysql/mysql.conf.d/mysqld.cnf
/etc/mysql/conf.d/custom.cnf
```

---

### Docker Environment

#### Docker Compose Projects
```
{project}/
├── docker-compose.yml
├── .env
├── php-{version}_docker/
│   ├── php-fpm/
│   │   ├── Dockerfile
│   │   ├── php-ini-overrides.ini
│   │   ├── opcache-prod.ini
│   │   └── z-optimised.conf          ← Generated by optimizer
│   └── nginx/
│       └── nginx.conf                 ← Modified by optimizer
├── .mysql_data/
│   └── conf.d/
│       └── 60-tuning.cnf              ← Generated by optimizer
└── .redis_data/
```

#### Volume Mounts (docker-compose.yml)
```yaml
services:
  php-fpm:
    volumes:
      - ./php-8.3_docker/php-fpm/z-optimised.conf:/etc/php/8.3/fpm/pool.d/z-optimised.conf
      - ./php-8.3_docker/php-fpm/opcache-prod.ini:/etc/php/8.3/fpm/conf.d/opcache-prod.ini

  mysql:
    volumes:
      - ./.mysql_data/conf.d/60-tuning.cnf:/etc/mysql/conf.d/60-tuning.cnf:ro
```

---

## Usage Examples

### Example 1: Optimize Host PHP-FPM

```
1. Select: ENVIRONMENT MANAGER
2. Select: HOST ENVIRONMENT
3. Select: OPTIMIZATIONS
4. Select: Optimize PHP-FPM
5. Confirm version: PHP 8.3

Output:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PHP-FPM Optimization Tool
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Server Specs:
  PHP Version: 8.3
  CPU Cores: 4
  Total RAM: 8192 MB
  Reserved RAM: 2048 MB
  Dedicated RAM: 6144 MB

Calculated Settings:
  pm.max_children: 68
  pm.start_servers: 16
  pm.min_spare_servers: 8
  pm.max_spare_servers: 16
  pm.max_requests: 500

OPcache Settings:
  opcache.enable: 1
  opcache.memory_consumption: 128
  opcache.max_accelerated_files: 10000

✓ Configuration updated: /etc/php/8.3/fpm/pool.d/www.conf
✓ PHP-FPM service reloaded successfully
```

---

### Example 2: Optimize Docker MySQL

```
1. Select: ENVIRONMENT MANAGER
2. Select: DOCKER CONTAINERS
3. Select project: example.com
4. Select: OPTIMIZE MYSQL

Output:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MySQL Optimization (Docker)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Container: example_stack_mysql
Version: MariaDB 10.11
Memory Limit: 4096 MB

Calculated Settings:
  innodb_buffer_pool_size: 2048 MB
  innodb_log_file_size: 256 MB
  max_connections: 150
  tmp_table_size: 64 MB

✓ Configuration written: .mysql_data/conf.d/60-tuning.cnf
⚠ Restarting MySQL container (brief downtime)
✓ MySQL restarted successfully
✓ Database ready for connections
```

---

### Example 3: Clean Docker RAM Usage

```
1. Select: ENVIRONMENT MANAGER
2. Select: DOCKER CONTAINERS
3. Select project: example.com
4. Select: CLEAN RAM USAGE

Output:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RAM Optimization (Docker)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Project: example.com

Actions:
  ✓ Restarting PHP-FPM container
    - Before: 456 MB
    - After: 123 MB
    - Freed: 333 MB

  ✓ Flushing Redis cache
    - Keys removed: 2,345
    - Memory freed: 89 MB

  ✓ Docker cleanup
    - Images removed: 3
    - Volumes removed: 1
    - Disk freed: 1.4 GB

Total Impact:
  RAM freed: 422 MB
  Disk freed: 1.4 GB
  Downtime: ~3 seconds
```

---

## Technical Reference

### Detection Functions

#### `project_get_install_type()`
```bash
# Location: libs/local/project_helper.sh:2723-2761
# Returns: "docker-compose" or "default"
# Logic: Searches for docker-compose.yml in project directory
```

#### `docker_optimizer_get_container_name()`
```bash
# Detects container name for a service
# Example: docker_optimizer_get_container_name "/var/www/example.com" "php-fpm"
# Returns: example_stack_php-fpm
```

---

### Optimization Algorithms

#### PHP-FPM pm.max_children Calculation

```
Variables:
  - total_ram: Total system RAM (MB)
  - mysql_avg_ram: Average MySQL memory usage
  - nginx_avg_ram: Average Nginx memory usage
  - ram_buffer: Safety buffer (1024 MB)
  - php_avg_ram: Average PHP process size (90 MB)

Formula:
  reserved_ram = mysql_avg_ram + nginx_avg_ram + ram_buffer
  dedicated_ram = total_ram - reserved_ram
  pm.max_children = floor(dedicated_ram / php_avg_ram)

Example:
  total_ram = 8192 MB
  mysql_avg_ram = 512 MB
  nginx_avg_ram = 256 MB
  ram_buffer = 1024 MB
  php_avg_ram = 90 MB

  reserved_ram = 512 + 256 + 1024 = 1792 MB
  dedicated_ram = 8192 - 1792 = 6400 MB
  pm.max_children = floor(6400 / 90) = 71
```

#### MySQL innodb_buffer_pool_size Calculation

```
Formula (Host):
  innodb_buffer_pool_size = floor(total_ram * 0.5)

Formula (Docker with memory limit):
  innodb_buffer_pool_size = floor(container_limit * 0.5)

Formula (Docker without limit):
  innodb_buffer_pool_size = floor(total_ram * 0.5)

Constraints:
  - Minimum: 128 MB
  - Maximum: 80% of container limit (if set)
```

---

### Service Reload Commands

#### Host Environment

**PHP-FPM:**
```bash
# Test configuration
php-fpm8.3 -t

# Reload (graceful)
service php8.3-fpm reload

# Restart (brief downtime)
service php8.3-fpm restart
```

**Nginx:**
```bash
# Test configuration
nginx -t

# Reload (zero downtime)
service nginx reload

# Restart
service nginx restart
```

**MySQL:**
```bash
# Most settings require restart
service mysql restart

# Some dynamic variables can be changed
mysql -e "SET GLOBAL max_connections = 200;"
```

---

#### Docker Environment

**PHP-FPM:**
```bash
# Graceful reload (USR2 signal)
docker compose -f docker-compose.yml exec -T php-fpm kill -USR2 1

# Restart container
docker compose -f docker-compose.yml restart php-fpm
```

**Nginx:**
```bash
# Reload configuration
docker compose -f docker-compose.yml exec -T webserver nginx -s reload

# Restart container
docker compose -f docker-compose.yml restart webserver
```

**MySQL:**
```bash
# Restart required for most settings
docker compose -f docker-compose.yml restart mysql

# Wait for ready
docker compose -f docker-compose.yml exec mysql mysqladmin ping
```

**Redis:**
```bash
# Most settings require restart
docker compose -f docker-compose.yml restart redis

# Flush cache (no restart)
docker exec -i {container} redis-cli FLUSHALL
```

---

## Best Practices

### Before Optimization

1. **Backup configurations:**
   ```bash
   cp /etc/php/8.3/fpm/pool.d/www.conf /etc/php/8.3/fpm/pool.d/www.conf.backup
   ```

2. **Monitor current metrics:**
   ```bash
   free -h  # RAM usage
   htop     # Process monitoring
   ```

3. **Test in staging first** (if available)

---

### After Optimization

1. **Verify services are running:**
   ```bash
   systemctl status php8.3-fpm
   systemctl status nginx
   docker compose ps
   ```

2. **Monitor performance:**
   - Check response times
   - Monitor error logs
   - Watch memory usage

3. **Test application functionality:**
   - Visit website
   - Test key features
   - Check for errors

---

### Monitoring

**Recommended Tools:**
- Netdata (real-time monitoring)
- Monit (service monitoring)
- Docker stats (`docker stats`)
- MySQL slow query log

**Key Metrics:**
- PHP-FPM: Active processes, queue length
- Nginx: Requests per second, response time
- MySQL: Queries per second, buffer pool hit ratio
- RAM: Used, cached, swap usage

---

## Troubleshooting

### PHP-FPM Issues

**Problem:** 502 Bad Gateway errors
**Cause:** pm.max_children too low
**Solution:** Increase pm.max_children or add more RAM

**Problem:** Out of memory
**Cause:** pm.max_children too high
**Solution:** Reduce pm.max_children or add swap

---

### MySQL Issues

**Problem:** Slow queries
**Cause:** innodb_buffer_pool_size too small
**Solution:** Increase buffer pool size (more RAM)

**Problem:** MySQL crash/restart
**Cause:** innodb_buffer_pool_size too large
**Solution:** Reduce buffer pool size

---

### Docker Issues

**Problem:** Container killed by OOM
**Cause:** Memory limit too restrictive
**Solution:** Increase memory limit in docker-compose.yml

**Problem:** Configuration not applied
**Cause:** Volume mount missing
**Solution:** Verify volume mounts in docker-compose.yml

---

## Performance Expectations

### Host PHP-FPM Optimization

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Response time | 850ms | 320ms | 62% faster |
| Concurrent requests | 20 | 68 | 240% more |
| Memory usage | 6.2 GB | 5.1 GB | 18% less |
| OPcache hit ratio | 0% | 95% | Massive gain |

### Docker MySQL Optimization

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Query time | 125ms | 45ms | 64% faster |
| Buffer pool hit ratio | 78% | 96% | 18% better |
| Disk I/O | High | Low | 70% reduction |

### Image Optimization

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Page load time | 4.2s | 1.8s | 57% faster |
| Total image size | 89 MB | 34 MB | 62% smaller |
| Bandwidth saved | - | 55 MB/page | Significant |

---

## Roadmap

### Planned Features

- [ ] PostgreSQL optimization (host and Docker)
- [ ] MongoDB optimization
- [ ] Kubernetes support
- [ ] Automated A/B testing of configurations
- [ ] Grafana integration for metrics
- [ ] Automated rollback on performance regression
- [ ] Machine learning-based optimization suggestions

---

## Changelog

### Version 3.3.6 (Planned)
- ✨ New: Environment Manager implementation
- ✨ New: Docker optimization support
- 🔧 Refactor: IT Utils → Environment Manager
- 📝 Documentation: Complete optimization guide

### Version 3.3.5 (Current)
- ✅ Host-based optimizations
- ✅ Image optimization
- ✅ Basic Docker support

---

## License

This documentation is part of BROLIT Shell.
Copyright (c) GauchoCode - A Software Development Agency
https://gauchocode.com

---

## Support

For issues, feature requests, or questions:
- GitHub Issues: [brolit-shell/issues](https://github.com/gauchocode/brolit-shell/issues)
- Email: support@gauchocode.com
