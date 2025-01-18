local exec = {}

local env = {
    _VERSION = _VERSION,
    _mode = "restricted",
    _G = {},
    
    print = print,
    pairs = pairs,
    string = string,
    table = table
}

local inject = [[
local arg = {...}
_ENV = arg[1]

for key, value in pairs(arg[2]) do
    _ENV[key] = value
end
]]

function exec.execute(src, args)
    local chunk, errorMsg = load(inject..' '..src)
    
    if not chunk then
        return nil, errorMsg --'422 Unprocessable Entity'
    end 
    
    return {chunk(env, args)}
end

return exec
