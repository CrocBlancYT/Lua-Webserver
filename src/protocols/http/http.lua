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
