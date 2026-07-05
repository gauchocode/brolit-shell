-- Routes API module for OpenResty
-- Provides REST API for managing nginx routes

local cjson = require "cjson"
local io = require "io"
local os = require "os"

local _M = {}

-- Config paths
local SITES_AVAILABLE = "/usr/local/openresty/nginx/conf/sites-available"
local SITES_ENABLED = "/usr/local/openresty/nginx/conf/sites-enabled"

-- Execute shell command and return output
local function shell(cmd)
    local handle = io.popen(cmd, "r")
    if not handle then return "" end
    local result = handle:read("*a")
    handle:close()
    return result
end

-- List all routes
function _M.list_routes()
    local routes = {}
    local output = shell("ls " .. SITES_AVAILABLE .. " 2>/dev/null")
    for domain in output:gmatch("[^\r\n]+") do
        if domain ~= "" and not domain:match("%.backup$") then
            local enabled = shell("test -L " .. SITES_ENABLED .. "/" .. domain .. " && echo true || echo false")
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
    local config_path = SITES_AVAILABLE .. "/" .. domain
    local f = io.open(config_path, "r")
    if not f then
        return nil, "Route not found"
    end
    local config = f:read("*a")
    f:close()

    local enabled = shell("test -L " .. SITES_ENABLED .. "/" .. domain .. " && echo true || echo false")
    return cjson.encode({
        domain = domain,
        enabled = enabled:gsub("%s+", "") == "true",
        config = config
    })
end

-- Create route
function _M.create_route(data)
    local domain = data.domain
    if not domain then
        return nil, "Domain is required"
    end

    local config = _M.generate_config(data)
    local config_path = SITES_AVAILABLE .. "/" .. domain

    local f = io.open(config_path, "w")
    if not f then
        return nil, "Cannot write config"
    end
    f:write(config)
    f:close()

    -- Create symlink
    os.execute("ln -sf " .. config_path .. " " .. SITES_ENABLED .. "/" .. domain)

    -- Reload nginx
    os.execute("openresty -s reload")

    return cjson.encode({success = true, domain = domain})
end

-- Delete route
function _M.delete_route(domain)
    os.execute("rm -f " .. SITES_ENABLED .. "/" .. domain)
    os.execute("mv " .. SITES_AVAILABLE .. "/" .. domain .. " " .. SITES_AVAILABLE .. "/" .. domain .. ".backup 2>/dev/null")
    os.execute("openresty -s reload")
    return cjson.encode({success = true, domain = domain})
end

-- Reload nginx
function _M.reload()
    local result = shell("openresty -t 2>&1")
    if result:find("successful") then
        os.execute("openresty -s reload")
        return cjson.encode({success = true, message = "Reloaded"})
    else
        return cjson.encode({success = false, error = result})
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

-- Generate nginx config
function _M.generate_config(data)
    local domain = data.domain
    local route_type = data.type or "proxy"
    local proxy_port = data.proxy_port or "80"

    if route_type == "proxy" then
        return [[server {
    listen 80;
    server_name ]] .. domain .. [[;

    access_log off;
    error_log /var/log/nginx/]] .. domain .. [[.error.log;

    keepalive_timeout 70;
    client_max_body_size 50m;

    location / {
        proxy_pass http://127.0.0.1:]] .. proxy_port .. [[;
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
}]]
    elseif route_type == "wordpress" then
        local php_version = data.php_version or "8.2"
        return [[server {
    listen 80;
    server_name ]] .. domain .. [[;
    root /var/www/]] .. domain .. [[;
    index index.php;

    access_log off;
    error_log /var/log/nginx/]] .. domain .. [[.error.log;

    location / {
        try_files $uri $uri/ /index.php?q=$uri&$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php]] .. php_version .. [[-fpm.sock;
    }
}]]
    end

    return nil, "Unknown route type: " .. tostring(route_type)
end

return _M
