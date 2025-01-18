local dataURL = {}

function dataURL.encode(content, mimeType, isBase64) --data:mimetype;[base64?],content
    local dataURL = 'data:'..(mimeType or '')
    if isBase64 then dataURL = dataURL .. ';base64' end
    return dataURL .. ',' .. content
end

-- lua socket's mime.unb64() doesn't completely work
local function base64_decode(data)
    local base64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    local data = string.gsub(data, '[^'..base64..'=]', '') --removes un-allowed characters and = signs

    local arranged = string.gsub(data, '.', function(x)
        if (x == '=') then return '' end

        local r, f = '', (string.find(base64, x) - 1) --locates the character in the base64 signs
        for i = 6, 1, -1 do --backwards loop because it's about binary
            r = r .. ((f % 2 ^ i - f % 2 ^ (i - 1)) > 0 and '1' or '0') --transforms base64 signs to binary
        end

        return r;
    end)

    local decoded = string.gsub(arranged, '%d%d%d%d%d%d%d%d', function(x)
        return string.char(tonumber(x, 2)) --convert text binary to actual characters (binary) (e.g '010010' -> ê)
    end)

    return decoded
end

function dataURL.decode(dataURL)  --data:(mimetype);([base64?]),(content)
    local metadata, data = dataURL:match('^(.-),(.-)$')
    local rawattributes = metadata:match('data:(.+)')

    local info = {}
    for attr in rawattributes:gmatch('([^;]+)') do
        local name, value = attr:match('(.+)=(.+)')

        if name and value then
            info[name] = value
        else
            if not info.mimetype then
                info.mimetype = attr
            else
                info[attr] = true
            end
        end
    end

    if info.base64 then
        data = base64_decode(data)
    end

    return data, info
end

return dataURL
