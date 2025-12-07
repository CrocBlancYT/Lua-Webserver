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
