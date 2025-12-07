local out = ''

local function add(path)
    local h = io.open(path, 'r')
    local content = h:read('*a')
    h:close()

    out = out .. 'do\n' .. content .. '\nend\n'
end

add("src/protocols/websocket/frame.lua")
add("src/protocols/websocket/sha1-binary.lua")
add("src/protocols/websocket/ws.lua")
add("src/protocols/http/http.lua")
add("src/server.lua")

local h = io.open('example/server-pack.lua', 'w+')
h:write(out)
h:close()