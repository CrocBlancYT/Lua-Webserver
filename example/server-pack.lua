do
frame = {}

local bit = require('bit')

function packI8(value)
    local result = ""
    for i = 7, 0, -1 do
        local byte = bit.band(bit.rshift(value, i * 8), 0xFF)
        result = result .. string.char(byte)
    end
    return result
end

function frame.encode(message)
    local fin_and_opcode = 0x81 -- FIN = 1, Opcode = 1 (Text frame)
    local payload_length = #message
    local frame = string.char(fin_and_opcode)

    if payload_length <= 125 then
        frame = frame .. string.char(payload_length)
    elseif payload_length <= 65535 then
        frame = frame .. string.char(126, bit.rshift(payload_length, 8), bit.band(payload_length, 0xFF))
    else
        error("Message too long!")
    end

    return frame .. message
end

function frame.decode(frame, new_data)
    frame.buffer = (frame.buffer or "") .. new_data

    if not frame.header_parsed then
        if #frame.buffer < 2 then
            return false
        end

        local first_byte = string.byte(frame.buffer, 1)
        local second_byte = string.byte(frame.buffer, 2)

        frame.fin = bit.band(first_byte, 0x80) ~= 0
        frame.opcode = bit.band(first_byte, 0x0F)
        frame.masked = bit.band(second_byte, 0x80) ~= 0
        frame.payload_length = bit.band(second_byte, 0x7F)
        frame.header_size = 2

        if frame.payload_length == 126 then
            frame.header_size = frame.header_size + 2
        elseif frame.payload_length == 127 then
            frame.header_size = frame.header_size + 8
        end

        if frame.masked then
            frame.header_size = frame.header_size + 4
        end

        if #frame.buffer < frame.header_size then
            return false
        end

        local offset = 3
        if frame.payload_length == 126 then
            frame.payload_length = bit.lshift(string.byte(frame.buffer, offset), 8) +
                                   string.byte(frame.buffer, offset + 1)
            offset = offset + 2
        elseif frame.payload_length == 127 then
            frame.payload_length = 0
            for i = 0, 7 do
                frame.payload_length = bit.lshift(frame.payload_length, 8) +
                                       string.byte(frame.buffer, offset + i)
            end
            offset = offset + 8
        end

        if frame.masked then
            frame.masking_key = { string.byte(frame.buffer, offset, offset + 3) }
            offset = offset + 4
        end

        frame.header_parsed = true
        frame.payload_start = offset
    end

    local payload_end = frame.payload_start + frame.payload_length - 1
    if #frame.buffer < payload_end then
        return false
    end

    frame.payload = frame.payload or ""
    for i = frame.payload_start, payload_end do
        local byte = string.byte(frame.buffer, i)
        if frame.masked then
            local mask_byte = frame.masking_key[(i - frame.payload_start) % 4 + 1]
            byte = bit.bxor(byte, mask_byte)
        end
        frame.payload = frame.payload .. string.char(byte)
    end

    frame.buffer = frame.buffer:sub(payload_end + 1)

    return true
end

end
do
local function ZERO()
    return {
       false, false, false, false,     false, false, false, false, 
       false, false, false, false,     false, false, false, false, 
       false, false, false, false,     false, false, false, false, 
       false, false, false, false,     false, false, false, false, 
    }
 end
 
 local hex_to_bits = {
    ["0"] = { false, false, false, false },
    ["1"] = { false, false, false, true  },
    ["2"] = { false, false, true,  false },
    ["3"] = { false, false, true,  true  },
 
    ["4"] = { false, true,  false, false },
    ["5"] = { false, true,  false, true  },
    ["6"] = { false, true,  true,  false },
    ["7"] = { false, true,  true,  true  },
 
    ["8"] = { true,  false, false, false },
    ["9"] = { true,  false, false, true  },
    ["A"] = { true,  false, true,  false },
    ["B"] = { true,  false, true,  true  },
 
    ["C"] = { true,  true,  false, false },
    ["D"] = { true,  true,  false, true  },
    ["E"] = { true,  true,  true,  false },
    ["F"] = { true,  true,  true,  true  },
 
    ["a"] = { true,  false, true,  false },
    ["b"] = { true,  false, true,  true  },
    ["c"] = { true,  true,  false, false },
    ["d"] = { true,  true,  false, true  },
    ["e"] = { true,  true,  true,  false },
    ["f"] = { true,  true,  true,  true  },
 }
 
 local function from_hex(hex)
  
     assert(type(hex) == 'string')
     assert(hex:match('^[0123456789abcdefABCDEF]+$'))
     assert(#hex == 8)
  
     local W32 = { }
  
     for letter in hex:gmatch('.') do
        local b = hex_to_bits[letter]
        assert(b)
        table.insert(W32, 1, b[1])
        table.insert(W32, 1, b[2])
        table.insert(W32, 1, b[3])
        table.insert(W32, 1, b[4])
     end
  
     return W32
  end
  
  local function COPY(old)
     local W32 = { }
     for k,v in pairs(old) do
        W32[k] = v
     end
  
     return W32
  end
  
  local function ADD(first, ...)
  
     local a = COPY(first)
  
     local C, b, sum
  
     for v = 1, select('#', ...) do
        b = select(v, ...)
        C = 0
  
        for i = 1, #a do
           sum = (a[i] and 1 or 0)
               + (b[i] and 1 or 0)
               + C
  
           if sum == 0 then
              a[i] = false
              C    = 0
           elseif sum == 1 then
              a[i] = true
              C    = 0
           elseif sum == 2 then
              a[i] = false
              C    = 1
           else
              a[i] = true
              C    = 1
           end
        end
        -- we drop any ending carry
  
     end
  
     return a
  end
  
  local function XOR(first, ...)
  
     local a = COPY(first)
     local b
     for v = 1, select('#', ...) do
        b = select(v, ...)
        for i = 1, #a do
           a[i] = a[i] ~= b[i]
        end
     end
  
     return a
  
  end
  
  local function AND(a, b)
  
     local c = ZERO()
  
     for i = 1, #a do
        -- only need to set true bits; other bits remain false
        if  a[i] and b[i] then
           c[i] = true
        end
     end
  
     return c
  end
  
  local function OR(a, b)
  
     local c = ZERO()
  
     for i = 1, #a do
        -- only need to set true bits; other bits remain false
        if  a[i] or b[i] then
           c[i] = true
        end
     end
  
     return c
  end
  
  local function OR3(a, b, c)
  
     local d = ZERO()
  
     for i = 1, #a do
        -- only need to set true bits; other bits remain false
        if a[i] or b[i] or c[i] then
           d[i] = true
        end
     end
  
     return d
  end
  
  local function NOT(a)
  
     local b = ZERO()
  
     for i = 1, #a do
        -- only need to set true bits; other bits remain false
        if not a[i] then
           b[i] = true
        end
     end
  
     return b
  end
  
  local function ROTATE(bits, a)
  
     local b = COPY(a)
  
     while bits > 0 do
        bits = bits - 1
        table.insert(b, 1, table.remove(b))
     end
  
     return b
  
  end
 
  local binary_to_hex = {
   ["0000"] = "0",
   ["0001"] = "1",
   ["0010"] = "2",
   ["0011"] = "3",
   ["0100"] = "4",
   ["0101"] = "5",
   ["0110"] = "6",
   ["0111"] = "7",
   ["1000"] = "8",
   ["1001"] = "9",
   ["1010"] = "a",
   ["1011"] = "b",
   ["1100"] = "c",
   ["1101"] = "d",
   ["1110"] = "e",
   ["1111"] = "f",
}

  function asHEX(a)
 
   local hex = ""
   local i = 1
   while i < #a do
      local binary = (a[i + 3] and '1' or '0')
                     ..
                     (a[i + 2] and '1' or '0')
                     ..
                     (a[i + 1] and '1' or '0')
                     ..
                     (a[i + 0] and '1' or '0')

      hex = binary_to_hex[binary] .. hex

      i = i + 4
   end

   return hex

end

 local x67452301 = from_hex("67452301")
 local xEFCDAB89 = from_hex("EFCDAB89")
 local x98BADCFE = from_hex("98BADCFE")
 local x10325476 = from_hex("10325476")
 local xC3D2E1F0 = from_hex("C3D2E1F0")
 
 local x5A827999 = from_hex("5A827999")
 local x6ED9EBA1 = from_hex("6ED9EBA1")
 local x8F1BBCDC = from_hex("8F1BBCDC")
 local xCA62C1D6 = from_hex("CA62C1D6")
 
 function sha1(msg)
  
     assert(type(msg) == 'string')
     assert(#msg < 0x7FFFFFFF) -- have no idea what would happen if it were large
  
     local H0 = x67452301
     local H1 = xEFCDAB89
     local H2 = x98BADCFE
     local H3 = x10325476
     local H4 = xC3D2E1F0
  
     local msg_len_in_bits = #msg * 8
  
     local first_append = string.char(0x80) -- append a '1' bit plus seven '0' bits
  
     local non_zero_message_bytes = #msg +1 +8 -- the +1 is the appended bit 1, the +8 are for the final appended length
     local current_mod = non_zero_message_bytes % 64
     local second_append = ""
     if current_mod ~= 0 then
        second_append = string.rep(string.char(0), 64 - current_mod)
     end
  
     -- now to append the length as a 64-bit number.
     local B1, R1 = math.modf(msg_len_in_bits  / 0x01000000)
     local B2, R2 = math.modf( 0x01000000 * R1 / 0x00010000)
     local B3, R3 = math.modf( 0x00010000 * R2 / 0x00000100)
     local B4     =            0x00000100 * R3
  
     local L64 = string.char( 0) .. string.char( 0) .. string.char( 0) .. string.char( 0) -- high 32 bits
              .. string.char(B1) .. string.char(B2) .. string.char(B3) .. string.char(B4) --  low 32 bits
  
  
  
     msg = msg .. first_append .. second_append .. L64         
  
     assert(#msg % 64 == 0)
  
     --local fd = io.open("/tmp/msg", "wb")
     --fd:write(msg)
     --fd:close()
  
     local chunks = #msg / 64
  
     local W = { }
     local start, A, B, C, D, E, f, K, TEMP
     local chunk = 0
  
     while chunk < chunks do
        --
        -- break chunk up into W[0] through W[15]
        --
        start = chunk * 64 + 1
        chunk = chunk + 1
  
        for t = 0, 15 do
           W[t] = from_hex(string.format("%02x%02x%02x%02x", msg:byte(start, start + 3)))
           start = start + 4
        end
  
        --
        -- build W[16] through W[79]
        --
        for t = 16, 79 do
           -- For t = 16 to 79 let Wt = S1(Wt-3 XOR Wt-8 XOR Wt-14 XOR Wt-16). 
           W[t] = ROTATE(1, XOR(W[t-3], W[t-8], W[t-14], W[t-16]))
        end
  
        A = H0
        B = H1
        C = H2
        D = H3
        E = H4
  
        for t = 0, 79 do
           if t <= 19 then
              -- (B AND C) OR ((NOT B) AND D)
              f = OR(AND(B, C), AND(NOT(B), D))
              K = x5A827999
           elseif t <= 39 then
              -- B XOR C XOR D
              f = XOR(B, C, D)
              K = x6ED9EBA1
           elseif t <= 59 then
              -- (B AND C) OR (B AND D) OR (C AND D
              f = OR3(AND(B, C), AND(B, D), AND(C, D))
              K = x8F1BBCDC
           else
              -- B XOR C XOR D
              f = XOR(B, C, D)
              K = xCA62C1D6
           end
  
           -- TEMP = S5(A) + ft(B,C,D) + E + Wt + Kt; 
           TEMP = ADD(ROTATE(5, A), f, E, W[t], K)
  
           --E = D; 　　D = C; 　　　C = S30(B);　　 B = A; 　　A = TEMP;
           E = D
           D = C
           C = ROTATE(30, B)
           B = A
           A = TEMP
  
           --printf("t = %2d: %s  %s  %s  %s  %s", t, A:HEX(), B:HEX(), C:HEX(), D:HEX(), E:HEX())
        end
  
        -- Let H0 = H0 + A, H1 = H1 + B, H2 = H2 + C, H3 = H3 + D, H4 = H4 + E. 
        H0 = ADD(H0, A)
        H1 = ADD(H1, B)
        H2 = ADD(H2, C)
        H3 = ADD(H3, D)
        H4 = ADD(H4, E)
     end
  
     return asHEX(H0) .. asHEX(H1) .. asHEX(H2) .. asHEX(H3) .. asHEX(H4)
 end
  
 local function hex_to_binary(hex)
     return hex:gsub('..', function(hexval)
                              return string.char(tonumber(hexval, 16))
                           end)
 end
  
function sha1_binary(msg)
     return hex_to_binary(sha1(msg))
end

end
do
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
end
do
http = {}

local status_codes = {  --important status codes
    ['101'] =  '101 Switching Protocols',
    ['200'] = '200 OK',
    ['202'] = '202 Accepted (Processing)',

    ['204'] = '204 No Content',
    ['206'] = '206 Partial Content',

    ['301'] = '301 Permanent Redirect',
    ['302'] = '302 Temporary Redirect', --302 Found

    ['400'] = "400 Bad Request",
    --['401'] = "401 Unauthorized",
    ['403'] = '403 Forbidden',
    ['404'] = "404 Not Found",
    ['405'] = '405 Method Not Allowed',
    ['410'] = "410 Gone",

    ['501'] = '501 Not Implemented',
    ['502'] = '501 Bad Gateway',
    ['503'] = '503 Service Unavailable',
    ['505'] = '505 HTTP Version Not Supported'
}


local function unescape(s)
    s = string.gsub(s, "+", " ")
    s = string.gsub(s, "%%(%x%x)", function (h)
            return string.char(tonumber(h, 16))
        end)
    return s
end

function http.receive(client)
    local ip = client:getpeername()
        
    local line, err = client:receive('*l')

    --path, method
    local _, _, method, rawpath, protocol = string.find(line, '^(.-) (.-) (.-)$')
    local _, _, path, args = string.find(rawpath, '^(.-)?(.-)$') --get the raw arguments from the url in the pattern: "url?args"

    local request = {
        client  = client,
        ip = ip,
    
        method = method,
        path = path or rawpath,
        protocol = protocol,
    
        args = {},
    
        headers = {},
        body = ''
    }
    
    --path args
    if path then
        local cgi = {}
        for name, value in string.gmatch(args, "([^&=]+)=([^&=]+)") do --http://url?arg=value
            local name = unescape(name)
            local value = unescape(value)
            cgi[name] = value
        end
        request.args = cgi
    end

    print(line)
    coroutine.yield()
    
    --headers
    while true do
        local line, err = client:receive('*l')

        if err then print(' error '..tostring(err)) break end
        if (line == '') or (not line) then break end
        local _, _, name, value = string.find(line, '^(.-): (.-)$')
        
        request.headers[string.lower(name)] = value

        print(line)
        coroutine.yield()
    end
    
    --body
    local content_length = request.headers['content-length']
    if content_length then
        request.body = client:receive(content_length)
    end
    print('Body: "'..tostring(request.body)..'"')

    return request
end

function http.send(client, response)
    local headers = response.headers or {}
    local body = response.body

    --default headers
    headers['date'] = os.date('%a, %d %b %Y %X GMT') --current date (weekday, day month year hour:minute:second timezone)
    headers['server'] = 'myLuaServer/1.x.x' --server name
    if body then headers['content-length'] = #body end --body length (if one is given)
    
    --sends status
    local status_code = tostring(response.status or 200)
    local status_message = status_codes[status_code] or status_codes['200']
    client:send('HTTP/1.1 '..status_message..'\r\n')

    --sends headers
    for key, value in pairs(headers) do
        client:send(key..': '..value..'\r\n')
    end

    --sends body (optionnal)
    if body then
        client:send('\n')
        client:send(body)
    end
end

local function getParams(content)
    local params = {}

    --REDO THE [;,] (; are to set paramaters to values (value;parameter=value) while , are to set a new value)
    for param in string.gmatch(content..';', '(.-)[;,] ?') do --for each (value), or (value);
        local _, _, name, value = string.find(param,'^(.-)=(.-)$')
        if (name and value) then
            params[name] = value
        else
            table.insert(params, param)
        end
    end
    return params
end
function http.header_to_table(rawcontent) --in works
    local header = {}
    
    for str in string.gmatch(rawcontent..',', '(.-),') do --pour chaque -> "(valeur),"
        for sub_header_name, rawcontent in string.gmatch(str..'() ', '(.-) ?%((.-)%) ') do --pour chaque () (groups de paramètres)
            if rawcontent == '' then
                table.insert(header, getParams(sub_header_name)) --rawcontent is empty -> the pattern  got a value that isn't between ()'s
            else
                header[sub_header_name] = getParams(rawcontent)
            end
        end
    end
    
    return header
end

end
do
server = {}

local socket = require('socket')

local http = http
local websocket = websocket

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

        local cor = coroutine.create(function () --on new clients
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

end
