--example file

dofile('server-pack.lua')
local s = server

local server, err = s.host('localhost:8000', 0)
server:setTimeout(10)
print(server.server, err or '')
print(server.url)

local server2, err = s.host('localhost:8080', 0)
server2:setTimeout(10)
print(server2.server, err or '')
print(server2.url)

--http example
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


--websocket example
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

server2:serve('GET', '/', 'HTTP/1.1', function (client, request)
    return {
        headers = {
            ['content-type'] = 'text/plain'
        },
        body = 'hallo'
    }
end)

while true do
    server:listen()
    server2:listen()
end