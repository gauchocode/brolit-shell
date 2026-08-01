-- Routes API module for OpenResty
-- Provides REST API for managing nginx routes
-- Requires bearer token auth via OPENRESTY_API_TOKEN env var

local cjson = require "cjson"
local io = require "io"
local os = require "os"

local _M = {}

-- Config paths
local SITES_AVAILABLE = "/usr/local/openresty/nginx/conf/sites-available"
local SITES_ENABLED = "/usr/local/openresty/nginx/conf/sites-enabled"
local CUSTOM_DIR = "/usr/local/openresty/nginx/conf/custom.d"
local LOG_DIR = "/var/log/openresty"
local WEBROOT_DIR = "/etc/brolit/certbot-webroot"
local SNIPPETS_DIR = "/usr/local/openresty/nginx/conf/snippets"
local LETSENCRYPT_DIR = "/etc/letsencrypt/live"
local TOKEN_FILE = "/usr/local/openresty/nginx/conf/.api_token"

-- Marker for brolit-managed configs
local BROLIT_MARKER = "# BROLIT-MANAGED"

-- Domain validation pattern (single domain or wildcard subdomain)
local function is_valid_domain(domain)
    if type(domain) ~= "string" or domain == "" then
        return false
    end
    -- Allow lowercase letters, digits, hyphen, dot, and leading * for wildcards
    return domain:match("^[a-zA-Z0-9%*%.%-_]+$") ~= nil
end

-- Validate upstream_url roughly
local function is_valid_upstream_url(url)
    if type(url) ~= "string" or url == "" then
        return false
    end
    return url:match("^https?://[%w%.%%%-%_:/?#=]+$") ~= nil
end

-- Read configured API token
local function get_api_token()
    local f = io.open(TOKEN_FILE, "r")
    if not f then
        return nil
    end
    local token = f:read("*l")
    f:close()
    if token then
        token = token:gsub("%s+", "")
    end
    return token
end

-- Check request Authorization header
local function check_auth()
    local expected = get_api_token()
    if not expected or expected == "" then
        return true
    end
    local auth = ngx.var.http_authorization or ""
    local token = auth:match("^Bearer%s+(%S+)$")
    if token == expected then
        return true
    end
    return false
end

-- Execute shell command and return output
local function shell(cmd)
    local handle = io.popen(cmd, "r")
    if not handle then return "" end
    local result = handle:read("*a")
    handle:close()
    return result
end

-- Shell escape for file/domain strings used in shell commands
local function shell_escape(str)
    return "'" .. str:gsub("'", "'\"'\"'") .. "'"
end

-- Ensure directories exist
local function ensure_directories()
    os.execute("mkdir -p " .. shell_escape(SITES_AVAILABLE))
    os.execute("mkdir -p " .. shell_escape(SITES_ENABLED))
    os.execute("mkdir -p " .. shell_escape(CUSTOM_DIR))
    os.execute("mkdir -p " .. shell_escape(LOG_DIR))
    os.execute("mkdir -p " .. shell_escape(WEBROOT_DIR .. "/.well-known/acme-challenge"))
end

-- List all routes
function _M.list_routes()
    ensure_directories()
    local routes = {}
    local output = shell("ls " .. shell_escape(SITES_AVAILABLE) .. " 2>/dev/null")
    for domain in output:gmatch("[^\r\n]+") do
        if domain ~= "" and not domain:match("%.backup$") then
            local enabled = shell("test -L " .. shell_escape(SITES_ENABLED .. "/" .. domain .. ".conf") .. " && echo true || echo false")
            table.insert(routes, {
                domain = domain,
                enabled = enabled:gsub("%s+", "") == "true"
            })
        end
    end
    return cjson.encode(routes)
end

-- Get single route
function _M.get_route(domain)
    if not is_valid_domain(domain) then
        return nil, "Invalid domain"
    end
    ensure_directories()
    local config_path = SITES_AVAILABLE .. "/" .. domain
    local f = io.open(config_path, "r")
    if not f then
        return nil, "Route not found"
    end
    local config = f:read("*a")
    f:close()

    local enabled = shell("test -L " .. shell_escape(SITES_ENABLED .. "/" .. domain .. ".conf") .. " && echo true || echo false")
    return cjson.encode({
        domain = domain,
        enabled = enabled:gsub("%s+", "") == "true",
        config = config
    })
end

-- Create route
function _M.create_route(data)
    ensure_directories()

    local domain = data.domain
    if not domain or not is_valid_domain(domain) then
        return nil, "Domain is required and must be a valid domain"
    end

    local upstream_url = data.upstream_url or ""
    if upstream_url ~= "" and not is_valid_upstream_url(upstream_url) then
        return nil, "Invalid upstream_url"
    end

    local config = _M.generate_config(data)
    if not config then
        return nil, "Failed to generate config"
    end
    local config_path = SITES_AVAILABLE .. "/" .. domain

    local f = io.open(config_path, "w")
    if not f then
        return nil, "Cannot write config"
    end
    f:write(config)
    f:close()

    -- Create symlink (".conf" suffix required: nginx.conf includes sites-enabled/*.conf)
    os.execute("ln -sf " .. shell_escape(config_path) .. " " .. shell_escape(SITES_ENABLED .. "/" .. domain .. ".conf"))

    -- Reload nginx (test first)
    local reload_result, reload_err = _M._reload()
    if not reload_result then
        return nil, "Config written but reload failed: " .. (reload_err or "")
    end

    return cjson.encode({success = true, domain = domain})
end

-- Delete route
function _M.delete_route(domain)
    if not is_valid_domain(domain) then
        return cjson.encode({success = false, error = "Invalid domain"})
    end
    ensure_directories()

    os.execute("rm -f " .. shell_escape(SITES_ENABLED .. "/" .. domain .. ".conf"))
    os.execute("mv " .. shell_escape(SITES_AVAILABLE .. "/" .. domain) .. " " .. shell_escape(SITES_AVAILABLE .. "/" .. domain .. ".backup") .. " 2>/dev/null")

    local reload_result, reload_err = _M._reload()
    if not reload_result then
        return cjson.encode({success = false, error = "Delete done but reload failed: " .. (reload_err or "")})
    end

    return cjson.encode({success = true, domain = domain})
end

-- Internal reload that returns true/false
--
-- The worker process runs as www-data, but the running master's pid/log
-- files are root-owned (nginx starts as root, drops privileges per-worker).
-- "openresty -t" run directly as www-data can't open those paths to
-- validate config, so it's invoked through a narrowly-scoped sudoers rule
-- (see the openresty-reload sudoers file installed alongside this API).
function _M._reload()
    local result = shell("sudo -n /usr/local/openresty/bin/openresty -t 2>&1")
    if result:find("successful") then
        os.execute("sudo -n /usr/local/openresty/bin/openresty -s reload")
        return true, nil
    else
        return false, result
    end
end

-- Public reload endpoint
function _M.reload()
    local ok, err = _M._reload()
    if ok then
        return cjson.encode({success = true, message = "Reloaded"})
    else
        return cjson.encode({success = false, error = err})
    end
end

-- Get status
function _M.status()
    local pid = shell("cat /usr/local/openresty/nginx/logs/nginx.pid 2>/dev/null")
    pid = pid:gsub("%s+", "")
    local running = pid ~= "" and pid ~= nil
    return cjson.encode({
        running = running,
        pid = pid
    })
end

-- Generate redirect server block for additional domains
local function generate_redirect_block(main_domain, redirect_domains)
    if not redirect_domains or redirect_domains == "" then
        return ""
    end
    local block = ""
    for domain in redirect_domains:gmatch("[^,]+") do
        domain = domain:gsub("^%s+", ""):gsub("%s+$", "")
        if is_valid_domain(domain) then
            block = block .. [[

server {
    listen 443 ssl http2;
    server_name ]] .. domain .. [[;

    ssl_certificate ]] .. LETSENCRYPT_DIR .. [[/]] .. main_domain .. [[/fullchain.pem;
    ssl_certificate_key ]] .. LETSENCRYPT_DIR .. [[/]] .. main_domain .. [[/privkey.pem;

    return 301 https://]] .. main_domain .. [[$request_uri;
}

server {
    listen 80;
    server_name ]] .. domain .. [[;

    location /.well-known/acme-challenge/ {
        root ]] .. WEBROOT_DIR .. [[;
    }

    location / {
        return 301 https://]] .. main_domain .. [[$request_uri;
    }
}]]
        end
    end
    return block
end

-- Generate nginx config
function _M.generate_config(data)
    local domain = data.domain
    local route_type = data.type or "proxy"
    local proxy_port = data.proxy_port or "80"
    local upstream_url = data.upstream_url or "http://127.0.0.1:" .. proxy_port
    local cert_name = data.cert_name or domain
    local redirect_domains = data.redirect_domains or ""

    local ssl_block = BROLIT_MARKER .. [[

server {
    listen 443 ssl http2;
    server_name ]] .. domain .. [[;

    ssl_certificate ]] .. LETSENCRYPT_DIR .. [[/]] .. cert_name .. [[/fullchain.pem;
    ssl_certificate_key ]] .. LETSENCRYPT_DIR .. [[/]] .. cert_name .. [[/privkey.pem;

    access_log off;
    error_log ]] .. LOG_DIR .. [[/]] .. domain .. [[.error.log;

    keepalive_timeout 70;
    client_max_body_size 50m;

    location / {
        proxy_pass ]] .. upstream_url .. [[;]]

    -- Add proxy_ssl_verify off for HTTPS upstreams
    if upstream_url:match("^https://") then
        ssl_block = ssl_block .. [[
        proxy_ssl_verify off;]]
    end

    ssl_block = ssl_block .. [[
        proxy_http_version 1.1;
        proxy_redirect off;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host $server_name;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        add_header X-Frame-Options SAMEORIGIN;
        add_header Strict-Transport-Security "max-age=31536000";
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";

        proxy_read_timeout 86400;
    }
}

server {
    listen 80;
    server_name ]] .. domain .. [[;

    location /.well-known/acme-challenge/ {
        root ]] .. WEBROOT_DIR .. [[;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}]]

    ssl_block = ssl_block .. generate_redirect_block(domain, redirect_domains)

    if route_type == "proxy" then
        return ssl_block

    elseif route_type == "wordpress" then
        local php_version = data.php_version or "8.2"
        local php_upstream = data.php_upstream or "unix:/run/php/php" .. php_version .. "-fpm.sock"
        return BROLIT_MARKER .. [[

server {
    listen 443 ssl http2;
    server_name ]] .. domain .. [[;
    root /var/www/]] .. domain .. [[;
    index index.php;

    ssl_certificate ]] .. LETSENCRYPT_DIR .. [[/]] .. cert_name .. [[/fullchain.pem;
    ssl_certificate_key ]] .. LETSENCRYPT_DIR .. [[/]] .. cert_name .. [[/privkey.pem;

    access_log off;
    error_log ]] .. LOG_DIR .. [[/]] .. domain .. [[.error.log;

    location / {
        try_files $uri $uri/ /index.php?q=$uri&$args;
    }

    location ~ \.php$ {
        include ]] .. SNIPPETS_DIR .. [[/fastcgi-php.conf;
        fastcgi_pass ]] .. php_upstream .. [[;
    }
}

server {
    listen 80;
    server_name ]] .. domain .. [[;

    location /.well-known/acme-challenge/ {
        root ]] .. WEBROOT_DIR .. [[;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}]]
    end

    return nil, "Unknown route type: " .. tostring(route_type)
end

-- Main request handler
function _M.handle()
    if not check_auth() then
        ngx.status = 401
        ngx.header.content_type = "application/json"
        ngx.say(cjson.encode({success = false, error = "Unauthorized"}))
        return ngx.exit(401)
    end

    local method = ngx.req.get_method()
    local uri = ngx.var.uri

    ngx.header.content_type = "application/json"

    if method == "GET" and uri == "/api/routes" then
        ngx.say(_M.list_routes())
    elseif method == "GET" and uri:match("^/api/routes/(.+)$") then
        local domain = uri:match("^/api/routes/(.+)$")
        local result, err = _M.get_route(domain)
        if result then
            ngx.say(result)
        else
            ngx.status = 404
            ngx.say(cjson.encode({success = false, error = err}))
        end
    elseif method == "POST" and uri == "/api/routes" then
        ngx.req.read_body()
        local body = ngx.req.get_body_data()
        if body then
            local ok, data = pcall(cjson.decode, body)
            if ok then
                local result, err = _M.create_route(data)
                if result then
                    ngx.say(result)
                else
                    ngx.status = 400
                    ngx.say(cjson.encode({success = false, error = err}))
                end
            else
                ngx.status = 400
                ngx.say(cjson.encode({success = false, error = "Invalid JSON"}))
            end
        else
            ngx.status = 400
            ngx.say(cjson.encode({success = false, error = "No body"}))
        end
    elseif method == "DELETE" and uri:match("^/api/routes/(.+)$") then
        local domain = uri:match("^/api/routes/(.+)$")
        ngx.say(_M.delete_route(domain))
    elseif method == "POST" and uri == "/api/reload" then
        ngx.say(_M.reload())
    elseif method == "GET" and uri == "/api/status" then
        ngx.say(_M.status())
    else
        ngx.status = 404
        ngx.say(cjson.encode({success = false, error = "Not found"}))
    end
end

return _M
