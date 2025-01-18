local s = dofile('server.lua')

local server, err = s.host('localhost:8000', 32)
server:setTimeout(10)

print(server.server, err or '')
print(server.url)

local json = require('json')
server:serve('GET', '/', 'HTTP/1.1', function (client, request)
    local payload = {
        'hello'
    }

    return {
        headers = {
            ['content-type'] = 'application/json'
        },
        body = json.encode(payload)
    }
end)


--websocket receive
local websocket = server:serve('GET', '/', 'websocket')

websocket.onOpen = function(client, init_request)
    print('NEW WS CLIENT')
    return 'welcome client'
end

websocket.onClose = function(client)
    print('WS CLIENT LOST')
end

websocket.onMessage = function (client, init_request, payload)
    print('payload', payload)
    return (payload or '(EMPTY PAYLOAD)')..' echo-ed'
end

while true do server:listen() end