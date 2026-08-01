-- Nginx API server configuration
-- Returns a server block for the brolit OpenResty management API
-- Authorization is enforced by routes.lua (bearer token)
-- Network access is restricted by allow/deny rules below

local _M = {}

function _M.get_api_server_block(allowed_network)
    allowed_network = allowed_network or "10.2.0.0/24"
    return [[
    # API Server (internal management only)
    server {
        listen 8080;
        server_name _;

        allow ]] .. allowed_network .. [[;
        deny all;

        # Lua API endpoint
        location /api/ {
            content_by_lua_block {
                require("routes").handle()
            }
        }

        location / {
            return 404;
        }
    }
]]
end

return _M
