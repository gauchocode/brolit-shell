-- Nginx API server configuration
-- This file is included in the main nginx.conf to add the API server block

local _M = {}

function _M.get_api_server_block()
    return [[
    # API Server (internal only)
    server {
        listen 8080;
        server_name _;

        # Lua API endpoint
        location /api/ {
            content_by_lua_block {
                local api = require "routes"
                local method = ngx.req.get_method()
                local uri = ngx.var.uri

                ngx.header.content_type = "application/json"

                if method == "GET" and uri == "/api/routes" then
                    ngx.say(api.list_routes())
                elseif method == "GET" and uri:match("/api/routes/(.+)") then
                    local domain = uri:match("/api/routes/(.+)")
                    local result, err = api.get_route(domain)
                    if result then
                        ngx.say(result)
                    else
                        ngx.status = 404
                        ngx.say('{"error":"' .. err .. '"}')
                    end
                elseif method == "POST" and uri == "/api/routes" then
                    ngx.req.read_body()
                    local body = ngx.req.get_body_data()
                    if body then
                        local ok, data = pcall(require("cjson").decode, body)
                        if ok then
                            local result, err = api.create_route(data)
                            if result then
                                ngx.say(result)
                            else
                                ngx.status = 400
                                ngx.say('{"error":"' .. err .. '"}')
                            end
                        else
                            ngx.status = 400
                            ngx.say('{"error":"Invalid JSON"}')
                        end
                    else
                        ngx.status = 400
                        ngx.say('{"error":"No body"}')
                    end
                elseif method == "DELETE" and uri:match("/api/routes/(.+)") then
                    local domain = uri:match("/api/routes/(.+)")
                    ngx.say(api.delete_route(domain))
                elseif method == "POST" and uri == "/api/reload" then
                    ngx.say(api.reload())
                elseif method == "GET" and uri == "/api/status" then
                    ngx.say(api.status())
                else
                    ngx.status = 404
                    ngx.say('{"error":"Not found"}')
                end
            }
        }
    }
]]
end

return _M
