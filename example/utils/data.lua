local json = require('json')
local lfs = require('lfs')

local data = { }

function data.file_contents(filePath, mode)
    local file = io.open(filePath, (mode or 'rb'))

    if not file then
        return false, 'no file found'
    end

    local content = file:read("*all")
    file:close()

    return content
end

local extenstion_to_mimetypes = {
    ['txt'] = 'text/plain',
    ['html'] = 'text/html',

    ['avif'] = 'image/avif',
    ['webp'] = 'image/webp',
    ['png'] = 'image/png',

    ['json'] = 'application/json',
    ['js'] = 'text/javascript',

    ['<unknown type>'] = 'application/octet-stream'
}

function data.fileName_to_mimetype(fileName) --can be a path
    local _, _, extension = string.find(fileName, '%.(.-)$')

    --check for debugging
    if not extension then
        return false, 'no extension'
    end

    return extenstion_to_mimetypes[extension]
end

local function save(handle, filepath)
    --check for debugging
    if not filepath then
        if type(handle) == "string" then
            return false, 'no handle provided (. instead of :)'
        else
            return false, 'no path provided'
        end
    end

    --json encoded (table -> string)
    local raw = json.encode(handle.data)

    --io set operation
    local h, ioerror = io.open(filepath, "w+")

    if not h then
        return false, ioerror
    end

    h:write(raw)
    h:close()

    return true
end

local function load(handle, filepath)
    --io get operation
    local h, ioerror = io.open(filepath, "r")

    if not h then
        return false, ioerror
    end

    local raw = h:read("*a")
    h:close()

    --json decoded(string -> table)
    local data = json.decode(raw)
    handle.data = data
    
    return data --truthy value
end

function data.new_json_handle()
    return {
        data = {},
        save = save,
        load = load
    }
end

local function split(str, pattern)
    local args = {}
    for str in string.gmatch(str, '([^'..pattern..']+)') do
        table.insert(args, str)
    end
    return args
end

function data.index_from_path(table, path)
    local args = split(path, '/')

    local previous = nil
    local indexed = table

    for _, index in pairs(args) do
        if (not indexed) or (not type(indexed) == "table") then
            return false, 'impossible to index path'
        end

        previous = indexed
        indexed = indexed[index] --new table to index
    end

    return indexed, previous --last table indexed
end

function data.getFileNames(dirPath)
    local fileNames = {}

    for file in lfs.dir(dirPath) do
        local isDir, _ = lfs.attributes(file, "mode")
        if not isDir then
            table.insert(fileNames, tostring(file))
        end
    end

    return fileNames
end

return data