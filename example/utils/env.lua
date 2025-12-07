local exec = {}

--libraries not included: os, io, ..

local env = {
    _VERSION = _VERSION,
    _mode = "restricted",
    _G = {},

    print = print,
    pairs = pairs,
    next = next,
    string = string,
    table = table,
    coroutine = coroutine
}

local inject = [[
do
    local env, args = ...

    env._G = args
    _ENV = env
end
]]

function exec.execute(src, args)
    local chunk, error = load(inject..'\n'..src)
    
    if not chunk then
        return nil, error
    end

    return {chunk(env, args)}
end

return exec
