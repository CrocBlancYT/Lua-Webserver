local data = {
    file = {},
    table = {}
}

local json = require('json')
local lfs = require('lfs')


local mimeTypes = {
    ['txt'] = 'text/plain',
    ['html'] = 'text/html',

    ['avif'] = 'image/avif',
    ['webp'] = 'image/webp',
    ['png'] = 'image/png',

    ['json'] = 'application/json',
    ['js'] = 'text/javascript',

    ['<unknown type>'] = 'application/octet-stream'
}


--modifies the contents of a file
function data.file.set(filePath, content, mode)
    local file = io.open(filePath, mode)
    if not file then return end

    file:write(content)
    file:close()
end

--gets the contents of a file
function data.file.get(filePath, mode)
    local file = io.open(filePath, mode)
    if not file then return end

    local content = file:read("*all")
    file:close()

    return content
end

function data.file.getFiles(DirName)
    local files = {}

    for file in lfs.dir(DirName) do
        local isDir, _ = lfs.attributes(file,"mode")
        if not isDir then
            table.insert(files, tostring(file))
        end
    end

    return files
end

--Interfaces a file as a table (in json)
function data.file.jsonWrap(filePath, loadOnIndex)
    --loadOnIndex : if set to true, the handle is refresh on every indexation
    
    local holder = {}

    local function clear()
        data.json.save(filePath, {})
    end

    local ext = {}
    setmetatable(ext,{
        __index = function (t, k)
            if loadOnIndex then
                data.json.load(filePath)
            end
            return holder[k]
        end,
        __newindex = function (t, k, v)
            holder[k] = v
            data.json.save(filePath, holder)
        end
    })

    return ext, clear
end


local function split(str, pattern)
    local args = {}
    for str in string.gmatch(str, '([^'..pattern..']+)') do
        table.insert(args, str)
    end
    return args
end

function data.table.get(table, path)
    local args = split(path, '/')

    local last = table
    for _, key in pairs(args) do
        if not (type(last) == "table") then return end

        local current = last[key]

        if not current then return end

        last = current
    end

    return last
end

function data.table.set(table, path, value)
    local args = split(path, '/')
    
    local final, key = table, args[#args]
    local last = table
    for _, key in pairs(args) do
        final = last
        local current = last[key]

        if not current then
            current = {}
            last[key] = current
        end

        last = current
    end

    final[key] = value
end

return data, mimeTypes