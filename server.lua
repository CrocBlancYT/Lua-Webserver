local server = {}

local socket = require('socket')

local http = dofile('http/http.lua')
local websocket = dofile('websocket/ws.lua')

local function setTimeout(server, time) server.timeout = time end

function table.find(tab, val)
    for i, v in pairs(tab) do
        if v == val then return i end
    end
end

local function normalizePath(path)
    if not path then return end
    return string.gsub(path, "^(.-)/*$", '%1') --removes extra /'s
end

local function serve(server, method, rawpath, protocol, func)
    local path = normalizePath(rawpath)

    local serve = {
        func = func,
        close = function ()
            local paths = server.serves[protocol]
            if not paths then return end

            local methods = paths[path]
            if not paths then return end
            
            methods[method] = nil
        end
    }

    --HTTP /welcome GET
    local protocols = server.serves

    local paths = protocols[protocol]
    if not paths then
        paths = {}
        protocols[protocol] = paths
    end

    local methods = paths[path]
    if not methods then 
        methods = {}
        paths[path] = methods
    end

    methods[method] = serve

    if protocol == 'websocket' then
        serve.onOpen = false
        serve.onClose = false
        serve.onMessage = false
    end

    return serve
end

local function process_data(server, client, data, ws_payload, ws_event)
    local protocols = server.serves

    --safely gets the serve (object being served)
    local paths = protocols[data.protocol]
    if not paths then print('nothing at protocol') return end

    local path = normalizePath(data.path)
    local methods = paths[path]
    if not methods then print('nothing at path') return end

    local serve = methods[data.method]
    if not serve then print('nothing at method') return end


    --calls the serve's method depending on the event
    if data.protocol == 'HTTP/1.1' then
        return serve.func(client, data)
    elseif data.protocol == 'websocket' then
        if ws_event == 'message' and serve.onMessage then
            return serve.onMessage(client, data, ws_payload)
        elseif ws_event == 'open' and serve.onOpen then
            return serve.onOpen(client, data)
        elseif ws_event == 'close' and serve.onClose then
            return serve.onClose(client)
        end
    end
end

local function listener(server)
    local sockets = server.sockets
    local threads = {}

    local function new_thread(client)
        local thread = {}
        
        --local _, _, _, mem_adr = string.find(tostring(client), '^(.-): (.-)$') --for debugging

        local cor = coroutine.create(function ()
            local request = http.receive(client)

            local headers = request.headers

            --upgrade protocol if needed
            local upgrade = headers['upgrade']
            if (upgrade) and (upgrade == 'websocket') then
                websocket.handshake(client, request)
                request.protocol = 'websocket'

                local response_payload = process_data(server, client, request, nil, 'open')
                if response_payload then
                    websocket.send(client, response_payload)
                end
                coroutine.yield()
                
                --websocket flow
                while true do
                    local data, error_message = websocket.receive(client)
                    
                    if error_message then  -- error -> the connection is closing
                        print('error', error_message)
                        request.error = error_message
                        process_data(server, client, request, nil, 'close')
                        break
                    end

                    local response_payload = process_data(server, client, request, data, 'message')

                    if response_payload then
                        websocket.send(client, response_payload)
                    end
                end
            else
                --http flow (1 iteration) // keep-alive not supported
                local response = process_data(server, client, request)

                http.send(client, response or {})
            end

            client:close()
            print('     client disconnected')
        end)

        function thread.resume()
            coroutine.resume(cor)
            
            if (coroutine.status(cor) == 'dead') then --self collection
                threads[client] = nil
                table.remove(sockets, table.find(sockets, client))
            end
        end
        
        threads[tostring(client)] = thread
        table.insert(sockets, client)
    end

    local function listen(server)
        local ready_to_read = socket.select(server.sockets)

        for _, socket in ipairs(ready_to_read) do
            if socket == server.server then
                local client = server.server:accept()

                local timeout = server.timeout
                if timeout then client:settimeout(server.timeout) end

                print('     new client')
                new_thread(client)
            else
                local thread = threads[tostring(socket)]
                thread.resume()
            end
        end
    end
    
    return listen
end

local function close(server) server.server:close() end

function server.host(host, backlog)
    local _, _, ip, port = string.find(host, '^(.*):(.-)$')

    if ip == '*' then
        ip = socket.dns.toip(socket.dns.gethostname()) --uses the ipv4 as default
    end

    local server, err = socket.bind(ip, port)

    local handle = {
        server = server,
        timeout = false,

        sockets = {server},
        serves = {},

        serve = serve,
        setTimeout = setTimeout,
        close = close,

        url = 'http://'..ip..':'..port
    }

    handle.listen = listener(handle)

    return handle, err
end

server.__docs__ = [[
s.host('host:port') {
    :setTimeout(time)
    :serve(method, path, protocol, function) { 
        (if websocket) : onOpen, onClose, onMessage
    }
    :listen()
    :close()
}



server:serve(method, path, 'HTTP/1.1', function(client, request)
    return {
        status = 200,
        headers = {},
        body = ''
    }
end)

request: table
response: table



websocket = server:serve(method, path, 'websocket')

websocket.onMessage = function (client, init_request, payload)
websocket.onOpen = function(client, init_request)
websocket.onClose = function(client)

init_request: table
payload: string
response: string
]]

return server