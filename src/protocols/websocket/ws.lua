local ws = {}

local mime = require('mime')
local sha1_binary = sha1_binary
local frame = frame

function ws.accept_key(key)
    local constant = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
    local hash = sha1_binary(key .. constant)
    return mime.b64(hash)
end

function ws.handshake(client, initial_request)
    local key = initial_request.headers['sec-websocket-key']
    local accept_key = ws.accept_key(key)

    client:send("HTTP/1.1 101 Switching Protocols\r\n")
    client:send("Upgrade: websocket\r\n")
    client:send("Connection: Upgrade\r\n")
    client:send("Sec-WebSocket-Accept: " .. accept_key .. "\r\n")
    client:send("\n")

    print("WebSocket handshake completed!")
end

function ws.receive(client)
    local process_frame = {}

    while true do
        local newdata, err = client:receive(1)
        if (not newdata) or (err) then process_frame.error = err break end

        local finished = frame.decode(process_frame, newdata)
        if finished then break end
        coroutine.yield()
    end

    return process_frame.payload, process_frame.error
end

function ws.send(client, payload)
    client:send(frame.encode(payload))
end

websocket = ws