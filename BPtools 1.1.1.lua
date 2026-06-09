script_name("BPtools")
script_author("@krankmode")
script_version("1.1.1")

local imgui = require("imgui")
local encoding = require 'encoding'
local ffi = require 'ffi'
local sampfuncs = require 'sampfuncs'
local raknet = require 'samp.raknet'
local sampeb = require('lib.samp.events')
encoding.default = 'CP1251'
u8 = encoding.UTF8

local window = imgui.ImBool(false)
local renderActive = imgui.ImBool(false)
local metalActive = imgui.ImBool(false)
local busActive = imgui.ImBool(false)
local inkasatorActive = imgui.ImBool(false)
local inkasatorActive2 = imgui.ImBool(false)
local autolActive = imgui.ImBool(false)

local font = renderCreateFont("Segoe UI", 11, 14) 

local triggerPattern = "[\xC7\xE7]\xE0\xE3\xF0\xF3\xE6\xE5\xED\xEE"

local letters_map = {}
local file_path = getWorkingDirectory() .. "\\BPtools\\alphabet_map.json"

local required_files = {
    { name = "sf6.route", url = "https://raw.githubusercontent.com/decetequsub67-gif/bptools-samp/refs/heads/main/sf6.route" },
    { name = "[AIRLS-1] Shamal.route", url = "https://raw.githubusercontent.com/decetequsub67-gif/bptools-samp/refs/heads/main/%5BAIRLS-1%5D%20Shamal.route" },
    { name = "Air1Shamal_POSLE POSADKI.route", url = "https://raw.githubusercontent.com/decetequsub67-gif/bptools-samp/refs/heads/main/Air1Shamal_POSLE%20POSADKI.route" }
}

local rpcs = {
    [26] = {'int16', 'bool'},
    [50] = {'int32', 'string'},
    [83] = {'int16'},
    [101] = {'int16', 'string'},
    [106] = {'int16', 'int32', 'int32', 'int8', 'int8'},
    [118] = {'int8'},
    [131] = {'int32'},
    [154] = {'int16'},
    [168] = {'int16', 'int16', 'int16', 'int16'},
    [177] = {'bool', 'int16', 'float', 'int32', 'int32'}
}
local odnotipnie_rpc = {83, 118, 131}

local vars = {
    state = false,
    lastVehicleSended = -1,
    route = {
        state = false,
        name = '',
        packets = 0,
        currentPos = { x = -1, y = -1, z = -1 },
        trailerId = -1
    }
}

function getObjectHandleBySampId(sampId)
    for _, handle in ipairs(getAllObjects()) do
        if doesObjectExist(handle) then
            if sampGetObjectIdByObjectHandle(handle) == sampId then
                return true, handle
            end
        end
    end
    return false, nil
end

function emulateCefEvent(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteString(bs, str)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function emulRpc(rpcId, data, send)
    if rpcs[rpcId] then
        local need_data = rpcs[rpcId]
        local bs = raknetNewBitStream()
        if #need_data > 0 then
            if #data == #need_data then
                for i = 1, #need_data do
                    local dataType, insertData = need_data[i], data[i]
                    if dataType == 'int8' then raknetBitStreamWriteInt8(bs, insertData) elseif dataType == 'int16' then raknetBitStreamWriteInt16(bs, insertData)
                    elseif dataType == 'int32' then raknetBitStreamWriteInt32(bs, insertData) elseif dataType == 'bool' then raknetBitStreamWriteBool(bs, insertData)
                    elseif dataType == 'string' then raknetBitStreamWriteString(bs, insertData) elseif dataType == 'float' then raknetBitStreamWriteFloat(bs, insertData)
                    elseif dataType == 'encoded' then raknetBitStreamEncodeString(bs, insertData) end
                end
            end
        end
        if send then raknetSendRpc(rpcId, bs) else raknetEmulRpcReceiveBitStream(rpcId, bs) end
        raknetDeleteBitStream(bs)
        return true
    end
    return false
end

function sendPlayerSync(x, y, z, mx, my, mz, qx, qy, qz, qw, keys, lrk, udk, hp, ar, sk, sact, fDel, loop, lX, lY, fr, ti, reg, animId, flags)
    local data                  = samp_create_sync_data('player')
    data.position               = { tonumber(x), tonumber(y), tonumber(z) }
    data.moveSpeed              = { tonumber(mx), tonumber(my), tonumber(mz) }
    data.quaternion[0]          = tonumber(qx)
    data.quaternion[1]          = tonumber(qy)
    data.quaternion[2]          = tonumber(qz)
    data.quaternion[3]          = tonumber(qw)
    data.keysData               = tonumber(keys)
    data.leftRightKeys          = tonumber(lrk)
    data.upDownKeys             = tonumber(udk)
    data.health                 = getCharHealth(1)
    data.armor                  = getCharArmour(1)
    data.specialKey             = tonumber(sk)
    data.specialAction          = tonumber(sact)
    data.animation = {
                    frameDelta   = tonumber(fDel),
                    id           = tonumber(animId),
                    flags = {loop   = loop == '1',
                    lockX  = lX == '1',
                    lockY  = lY == '1',
                    freeze = fr == '1',
                    time   = tonumber(ti),
                    regular= reg == '1'}
    }
    data.animationId            = tonumber(animId)
    data.animationFlags         = tonumber(flags)
    data.send()
end

function sendIncarSync(x, y, z, mx, my, mz, qx, qy, qz, qw, keys, kkeys, upd, lean, trailer, tx, ty, tz, tmx, tmy, tmz, tqx, tqy, tqz, tqw, ttx, tty, ttz, trx, try, trz, tdx, tdy, tdz, tsx, tsy, tsz, unk)
    local data          = samp_create_sync_data('vehicle')
    data.position       = { tonumber(x), tonumber(y), tonumber(z) }
    data.moveSpeed      = { tonumber(mx), tonumber(my), tonumber(mz) }
    data.quaternion[0]  = tonumber(qx)
    data.quaternion[1]  = tonumber(qy)
    data.quaternion[2]  = tonumber(qz)
    data.quaternion[3]  = tonumber(qw)
    data.keysData       = tonumber(keys)
    data.leftRightKeys  = tonumber(kkeys)
    data.upDownKeys     = tonumber(upd)
    data.bikeLean       = tonumber(lean)
    if isCharInAnyCar(1) or vars.lastVehicleSended ~= -1 then
        data.vehicleId  = isCharInAnyCar(1) and select(2, sampGetVehicleIdByCarHandle(storeCarCharIsInNoSave(1))) or vars.lastVehicleSended
    end
    if trailer then
        data.trailerId = trailer
        data.send()
        local sync = samp_create_sync_data('trailer')
        sync.trailerId = trailer
        sync.position = { tonumber(tx), tonumber(ty), tonumber(tz) }
        sync.moveSpeed = { tonumber(tmx), tonumber(tmy), tonumber(tmz) }
        sync.quaternion[0]  = tonumber(tqx)
        sync.quaternion[1]  = tonumber(qy)
        sync.quaternion[2]  = tonumber(qz)
        sync.quaternion[3]  = tonumber(qw)
        sync.turnSpeed = { tonumber(ttx), tonumber(tty), tonumber(ttz) }
        sync.roll = { tonumber(trx), tonumber(try), tonumber(trz) }
        sync.direction = { tonumber(tdx), tonumber(tdy), tonumber(tdz) }
        sync.speed = { tonumber(tsx), tonumber(tsy), tonumber(tsz) }
        sync.unk = tonumber(unk)
        sync.send()
    else
        data.send()
    end
end

function samp_create_sync_data(sync_type, copy_from_player)
    copy_from_player = (copy_from_player == nil) and true or copy_from_player
    local internal_types = {
        player = {'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData},
        vehicle = {'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData},
        passenger = {'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData},
        aim = {'AimSyncData', raknet.PACKET.AIM_SYNC, sampStorePlayerAimData},
        trailer = {'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, sampStorePlayerTrailerData}
    }
    local sync_info = internal_types[sync_type]
    
    local data = ffi.new(sync_info[1] .. "[1]")
    local raw_data_ptr = tonumber(ffi.cast('uintptr_t', data))
    
    if copy_from_player and sync_info[3] then
        local _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
        sync_info[3](player_id, raw_data_ptr)
    end
    
    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sync_info[2])
        raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(sync_info[1]))
        raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
        raknetDeleteBitStream(bs)
    end
    
    local mt = {
        __index = function(t, index) return data[0][index] end,
        __newindex = function(t, index, value) data[0][index] = value end
    }
    return setmetatable({send = func_send}, mt)
end

function getClosestCarWithModel(model)
    local id, dist = -1, 9999
    for i = 0, 2000 do
        local z, v = sampGetCarHandleBySampVehicleId(i)
        if z then
            local my, car = {getCharCoordinates(1)}, {getCharCoordinates(v)}
            local distan = getDistanceBetweenCoords3d(my[1], my[2], my[3], car[1], car[2], car[3])
            if getCarModel(v) == model and distan < dist then
                dist = distan
                id = i
            end
        end
    end
    return id
end

function sendAtmSuccessDropPacket()
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, 19)
    raknetBitStreamWriteString(bs, "atmGame.successDrop")
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.RELIABLE_ORDERED, 0)
    raknetDeleteBitStream(bs)
end

function vars.route_onSendPlayerSync(data)
    if vars.route.state then return false end
end

function vars.route_onSendVehicleSync(data)
    if vars.route.state then return false end
end

function vars.route_onSendTrailerSync(data)
    if vars.route.state then return false end
end

function vars.route_onSendAimSync(data)
    if vars.route.state then return false end
end

function sampeb.onReceivePacket(id, bs)
    if id == 220 and inkasatorActive.v then
        local ptr = raknetBitStreamGetDataPtr(bs)
        local len = raknetBitStreamGetNumberOfBytesUsed(bs)
        if ptr ~= 0 and len > 0 then
            local data = ffi.string(ffi.cast("char*", ptr), len)
            if data:find("atmGame") and not data:find("successDrop") then
                lua_thread.create(function()
                    wait(600)
                    sendAtmSuccessDropPacket()
                    sampAddChatMessage("[BPtools]: {00FF00}Мини-игра ATM автоматически пройдена!", 0xFFFFFFFF)
                end)
            end
        end
    end
end

function autoLProcessor()
    local last_detected_letter = ""
    while true do
        wait(150)
        if autolActive.v then
            local result, handle = getObjectHandleBySampId(2992)
            if result and doesObjectExist(handle) then
                local x, y, z = getObjectCoordinates(handle)
                local found = false
                for _, item in ipairs(letters_map) do
                    if math.abs(x - item.x) < 0.05 and math.abs(y - item.y) < 0.05 then
                        found = true
                        if last_detected_letter ~= item.name then
                            last_detected_letter = item.name
                            sampAddChatMessage("[BPtools]: {FFFF00}Маркер встал на букву: " .. item.name, 0xFFFFFFFF)
                        end
                        break
                    end
                end
                if not found then
                    last_detected_letter = ""
                end
            else
                last_detected_letter = ""
            end
        else
            last_detected_letter = ""
        end
    end
end

function routePlayBack()
    while true do wait(0)
        if vars.route.state and vars.route.name ~= '' then
            local file_path = getWorkingDirectory()..'\\BPtools\\'..vars.route.name
            if doesFileExist(file_path) then
                local totalLines = 0
                for _ in io.lines(file_path) do 
                    totalLines = totalLines + 1 
                end

                local file = io.open(file_path, 'r')
                local r = file:read('*all')
                file:close()

                local stime = 50
                local px, py, pz = 1, 1, 1
                local q_x, q_y, q_z, q_w = 1, 1, 1, 1
                if isCharInAnyCar(1) then
                    freezeCarPosition(storeCarCharIsInNoSave(1), true)
                else
                    freezeCarPosition(1, true)
                end

                for line in r:gmatch('[^\r\n]+') do
                    local v = line
                    if not v or not (vars.route.state and vars.route.name ~= '') then break end
                    
                    vars.route.packets = vars.route.packets + 1
                    printStringNow(string.format("~p~%d / %d", vars.route.packets, totalLines), 200)

                    if v:find('Trailer') then
                        local r1, r2 = v:match("Vehicle(.*); Trailer(.*)")
                        if r1 and r2 then
                            local x, y, z, mx, my, mz, qx, qy, qz, qw, kd, lrk, udk, bl = r1:match('%[%((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+); (%S+)%); (%S+); (%S+); (%S+); (%S+)%]')
                            local tx, ty, tz, tmx, tmy, tmz, tqx, tqy, tqz, tqw, ttx, tty, ttz, trx, try, trz, tdx, tdy, tdz, tsx, tsy, tsz, unk, timer = r2:match('%[%((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+); (%S+)%]); %((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+)%); (%S+); (%S+)%]')
                            if x then
                                px, py, pz = x, y, z
                                q_x, q_y, q_z, q_w = qx, qy, qz, qw
                                stime = timer
                                if vars.route.trailerId ~= -1 then
                                    local _, veh = sampGetCarHandleBySampVehicleId(vars.route.trailerId)
                                    if _ then
                                        sendIncarSync(x, y, z, mx, my, mz, qx, qy, qz, qw, kd, lrk, udk, bl, vars.route.trailerId, tx, ty, tz, tmx, tmy, tmz, tmz, tqx, tqy, tqz, tqw, ttx, tty, ttz, trx, try, trz, tdx, tdy, tdz, tsx, tsy, tsz, unk)
                                        if not isTrailerAttachedToCab(storeCarCharIsInNoSave(1), veh) then
                                            attachTrailerToCab(veh, storeCarCharIsInNoSave(1))
                                        end
                                    end
                                else
                                    sendIncarSync(x, y, z, mx, my, mz, qx, qy, qz, qw, kd, lrk, udk, bl)
                                end
                            end
                        end
                    elseif v:find('Vehicle') and not v:find('Trailer') then
                        local x, y, z, mx, my, mz, qx, qy, qz, qw, kd, lrk, udk, bl, timer = v:match('%[%((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+); (%S+)%); (%S+); (%S+); (%S+); (%S+); (%S+)%]')
                        if x then
                            q_x, q_y, q_z, q_w = qx, qy, qz, qw
                            px, py, pz = x, y, z
                            stime = timer
                            sendIncarSync(x, y, z, mx, my, mz, qx, qy, qz, qw, kd, lrk, udk, bl)
                        end
                    elseif v:find('Player') then
                        local x, y, z, mx, my, mz, qx, qy, qz, qw, hp, arm, spAct, spKey, anLoop, anLX, anLY, anFR, anREG, anFD, anTime, animId, animFlags, kd, lrk, udk, timer = v:match('%[%((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+); (%S+)%); %((%S+); (%S+)%); (%S+); (%S+); %((%S+); (%S+); (%S+); (%S+); (%S+); (%S+); (%S+)%); %((%S+); (%S+)%); %((%S+); (%S+); (%S+)%); (%S+)%]')
                        if x then
                            px, py, pz = x, y, z
                            q_x, q_y, q_z, q_w = qx, qy, qz, qw
                            stime = timer
                            sendPlayerSync(x, y, z, mx, my, mz, qx, qy, qz, qw, kd, lrk, udk, hp, arm, spKey, spAct, anFD, anLoop, anLX, anLY, anFR, anTime, anREG, animId, animFlags)
                        end
                    elseif v:find('Aim') then
                        local cm, fx, fy, fz, px_aim, py_aim, pz_aim, aimz, cez, ws, ar = v:match('%[%((%S+); %((%S+); (%S+); (%S+)%); %((%S+); (%S+); (%S+)%); (%S+); (%S+); (%S+); (%S+)%]')
                        if cm then
                            stime = -1
                            local data = samp_create_sync_data('aim')
                            data.camMode = tonumber(cm)
                            data.camFront, data.camPos = { tonumber(fx), tonumber(fy), tonumber(fz) }, { tonumber(px_aim), tonumber(py_aim), tonumber(pz_aim) }
                            data.aimZ = tonumber(aimz)
                            data.camExtZoom = tonumber(cez)
                            data.weaponState = tonumber(ws)
                            data.aspectRatio = tonumber(ar)
                            data.send()
                        end
                    elseif v:find('RPC') then
                        stime = -1
                        local send = v:find('RPCS')
                        local receive = v:find('RPCR')
                        if send then
                            local rpcId = tonumber(v:match('RPCS%((%S+)%)'))
                            if rpcId then
                                local dataToSend = {}
                                if rpcId == 26 then
                                    local vehid, passenger, model = v:match('RPCS%(%S+%)%[(%S+); (%S+); (%S+)%]')
                                    if vehid then
                                        vehid, passenger, model = tonumber(vehid), (passenger == '1'), tonumber(model)
                                        local _, veh = sampGetCarHandleBySampVehicleId(vehid)
                                        if _ then
                                            vars.lastVehicleSended = vehid
                                            dataToSend = {vehid, passenger}
                                            warpCharIntoCar(1, veh)
                                        else
                                            local id = getClosestCarWithModel(model)
                                            if id ~= -1 then
                                                warpCharIntoCar(1, select(2, sampGetCarHandleBySampVehicleId(id)))
                                                vars.lastVehicleSended = id
                                                dataToSend = {vehid, passenger}
                                            else
                                                if isCharInAnyCar(1) then
                                                    vars.lastVehicleSended = select(2, sampGetVehicleIdByCarHandle(storeCarCharIsInNoSave(1)))
                                                    dataToSend = {vars.lastVehicleSended, false}
                                                end
                                            end
                                        end
                                        emulRpc(rpcId, dataToSend, true)
                                    end
                                elseif rpcId == 50 or rpcId == 101 then
                                    local msg = v:match('RPCS%(%S+%)%[(%S+)%]')
                                    if msg then
                                        dataToSend = {msg:len(), msg}
                                        emulRpc(rpcId, dataToSend, true)
                                    end
                                elseif rpcId == 154 then
                                    dataToSend = {vars.lastVehicleSended ~= -1 and vars.lastVehicleSended or (isCharInAnyCar(1) and select(2, sampGetVehicleIdByCarHandle(storeCarCharIsInNoSave(1))) or -1)}
                                    warpCharFromCarToCoord(1, vars.route.currentPos.x, vars.route.currentPos.y, vars.route.currentPos.z)
                                    emulRpc(rpcId, dataToSend, true)
                                elseif rpcId == 168 then
                                    local z, zov, svo, pasxalkoo = v:match('RPCS%(%S+%)%[(%S+); (%S+); (%S+); (%S+)%]')
                                    if z then
                                        dataToSend = {tonumber(z), tonumber(zov), tonumber(svo), tonumber(pasxalkoo)}
                                        emulRpc(rpcId, dataToSend, true)
                                    end
                                else
                                    for k,vl in pairs(odnotipnie_rpc) do
                                        if rpcId == vl then
                                            local val = v:match('RPCS%(%S+%)%[(%S+)%]')
                                            if val then
                                                dataToSend = {tonumber(val)}
                                                emulRpc(rpcId, dataToSend, true)
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        elseif receive then
                            local rpcId = tonumber(v:match('RPCR%((%S+)%)'))
                            if rpcId then
                                local dataToSend = {}
                                if rpcId == 26 then
                                    local vehid, passenger, model = v:match('RPCR%(%S+%)%[(%S+); (%S+); (%S+)%]')
                                    if vehid then
                                        vehid, passenger, model = tonumber(vehid), (passenger == '1'), tonumber(model)
                                        local _, veh = sampGetCarHandleBySampVehicleId(vehid)
                                        if _ then
                                            vars.lastVehicleSended = vehid
                                            dataToSend = {vehid, passenger}
                                            warpCharIntoCar(1, veh)
                                        else
                                            local id = getClosestCarWithModel(model)
                                            if id ~= -1 then
                                                warpCharIntoCar(1, select(2, sampGetVehicleIdByCarHandle(id)))
                                                vars.lastVehicleSended = id
                                                dataToSend = {vehid, passenger}
                                            else
                                                if isCharInAnyCar(1) then
                                                    vars.lastVehicleSended = select(2, sampGetVehicleIdByCarHandle(storeCarCharIsInNoSave(1)))
                                                    dataToSend = {vars.lastVehicleSended, false}
                                                end
                                            end
                                        end
                                        emulRpc(rpcId, dataToSend, false)
                                    end
                                elseif rpcId == 50 or rpcId == 101 then
                                    local msg = v:match('RPCR%(%S+%)%[(%S+)%]')
                                    if msg then
                                        dataToSend = {msg:len(), msg}
                                        emulRpc(rpcId, dataToSend, false)
                                    end
                                elseif rpcId == 154 then
                                    dataToSend = {vars.lastVehicleSended ~= -1 and vars.lastVehicleSended or -1}
                                    warpCharFromCarToCoord(1, vars.route.currentPos.x, vars.route.currentPos.y, vars.route.currentPos.z)
                                    emulRpc(rpcId, dataToSend, false)
                                elseif rpcId == 168 then
                                    local z, zov, svo, pasxalkoo = v:match('RPCR%(%S+%)%[(%S+); (%S+); (%S+); (%S+)%]')
                                    if z then
                                        dataToSend = {tonumber(z), tonumber(zov), tonumber(svo), tonumber(pasxalkoo)}
                                        emulRpc(rpcId, dataToSend, false)
                                    end
                                else
                                    for k,vl in pairs(odnotipnie_rpc) do
                                        if rpcId == vl then
                                            local val = v:match('RPCR%(%S+%)%[(%S+)%]')
                                            if val then
                                                dataToSend = {tonumber(val)}
                                                emulRpc(rpcId, dataToSend, false)
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    if px and py and pz then
                        vars.route.currentPos = {x = tonumber(px), y = tonumber(py), z = tonumber(pz)}
                        if isCharInAnyCar(1) then
                            setCarCoordinatesNoOffset(storeCarCharIsInNoSave(1), vars.route.currentPos.x, vars.route.currentPos.y, vars.route.currentPos.z)
                            setVehicleQuaternion(storeCarCharIsInNoSave(1), tonumber(q_y), tonumber(q_z), tonumber(q_w), -tonumber(q_x))
                        else
                            setCharCoordinatesNoOffset(1, vars.route.currentPos.x, vars.route.currentPos.y, vars.route.currentPos.z)
                            setCharQuaternion(1, tonumber(q_y), tonumber(q_z), tonumber(q_w), -tonumber(q_x))
                        end
                    end
                    
                    if stime ~= -1 and tonumber(stime) then
                        wait(tonumber(stime))
                    end
                end
                vars.route.packets = 0
                vars.route.state = false
                vars.route.name = ''
                if isCharInAnyCar(1) then
                    freezeCarPosition(storeCarCharIsInNoSave(1), false)
                else
                    freezeCarPosition(1, false)
                end
            else
                sampAddChatMessage("[BPtools]: {FF0000}Файл маршрута не найден!", 0xFFFFFFFF)
                vars.route.state = false
                vars.route.name = ''
            end
        end
    end
end

function main()
    while not isSampAvailable() do wait(200) end
    
    if thisScript().filename ~= "BPtools 1.1.1.lua" then
        sampAddChatMessage("[BPtools]: {FF0000}Переименование запрещено! Скрипт отключен.", 0xFFFFFFFF)
        thisScript():unload()
        return
    end

    apply_purple_transparent_style()
    
    sampeb.onSendPlayerSync = vars.route_onSendPlayerSync
    sampeb.onSendVehicleSync = vars.route_onSendVehicleSync
    sampeb.onSendTrailerSync = vars.route_onSendTrailerSync
    sampeb.onSendAimSync = vars.route_onSendAimSync
    
    local files_dir = getWorkingDirectory()..'\\BPtools'
    if not doesDirectoryExist(files_dir) then
        createDirectory(files_dir)
    end
    
    if doesFileExist(file_path) then
        local file = io.open(file_path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            local ok, json = pcall(decodeJson, content)
            if ok and json then 
                letters_map = json 
            end
        end
    end

    for _, file in ipairs(required_files) do
        local filepath = files_dir .. '\\' .. file.name
        if not doesFileExist(filepath) then
            sampAddChatMessage("[BPtools]: {FFFF00}Авто-загрузка файла: " .. file.name, 0xFFFFFFFF)
            downloadUrlToFile(file.url, filepath, function(id, status, p1, p2)
                if status == 6 then
                    sampAddChatMessage("[BPtools]: {00FF00}Файл " .. file.name .. " успешно загружен!", 0xFFFFFFFF)
                end
            end)
        end
    end
    
    lua_thread.create(routePlayBack)
    lua_thread.create(autoLProcessor)

    sampRegisterChatCommand('btools', function()
        window.v = not window.v
    end)

    sampRegisterChatCommand("setletter", function(param)
        if param == "" then
            sampAddChatMessage("[BPtools]: {FF0000}Укажите букву! Пример: /setletter Л", 0xFFFFFFFF)
            return
        end
        
        local result, handle = getObjectHandleBySampId(2992)
        if result and doesObjectExist(handle) then
            local x, y, z = getObjectCoordinates(handle)
            
            local updated = false
            for _, item in ipairs(letters_map) do
                if item.name == param then
                    item.x, item.y, item.z = x, y, z
                    updated = true
                    break
                end
            end
            
            if not updated then
                table.insert(letters_map, {x = x, y = y, z = z, name = param})
            end
            
            local file = io.open(file_path, "w")
            if file then
                file:write(encodeJson(letters_map))
                file:close()
            end
            
            sampAddChatMessage(string.format("[BPtools]: {00FF00}Буква '%s' успешно привязана! (X: %.2f | Y: %.2f)", param, x, y), 0xFFFFFFFF)
        else
            sampAddChatMessage("[BPtools]: {FF0000}Объект 2992 не найден в зоне стрима!", 0xFFFFFFFF)
        end
    end)

    while true do
        wait(0)
        
        imgui.Process = window.v
        
        if inkasatorActive2.v then
            if not sampIsChatInputActive() and not sampIsDialogActive() and not isSampfuncsConsoleActive() then
                emulateCefEvent("atmGame.successDrop")
            end
        end
        
        if renderActive.v then
            local resX, resY = getScreenResolution()
            local centerX, centerY = resX / 2, resY / 2

            for id = 0, 2048 do
                local result = sampIs3dTextDefined(id)
                if result then
                    local text, color, posX, posY, posZ, distance, ignoreWalls, playerId, vehicleId = sampGet3dTextInfoById(id)
                    
                    if text:find(triggerPattern) or text:find("%d+/%d+%%") then
                        if isPointOnScreen(posX, posY, posZ, 1) then
                            local wposX, wposY = convert3DCoordsToScreen(posX, posY, posZ)
                            
                            if wposX < resX and wposY < resY then
                                local cleanText = text:gsub("{%x%x%x%x%x%x}", "")
                                
                                renderDrawLine(centerX, centerY, wposX, wposY, 1.5, 0xFF00FF00)
                                renderFontDrawText(font, cleanText, wposX + 10, wposY - 10, 0xFFFFFFFF)
                            end
                        end
                    end
                end
            end
        end
    end
end

function sampeb.onShowDialog(dialogId, style, title, button1, button2, text)
    if metalActive.v then
        if title:find("\xD1\xEF\xE8\xF1\xEE\xEA\x20\xE2\xFB\xE7\xEE\xE2\xEE\xE2") then
            local minDistance = 999999
            local bestItemIdx = -1
            local bestLineText = ""
            
            local lineIdx = 0
            local currentItemIdx = 0
            
            for line in text:gmatch("[^\r\n]+") do
                local isHeaderLine = (style == 5 and lineIdx == 0)
                
                if line:find("\xF1\xE2\xEE\xE1\xEE\xE4\xE5\xED") then
                    local cleanLine = line:gsub("{%x%x%x%x%x%x}", "")
                    local distStr = cleanLine:match("([%d%.]+)%s*\xEC")
                    local distance = tonumber(distStr)
                    
                    if distance then
                        if distance < minDistance then
                            minDistance = distance
                            bestItemIdx = currentItemIdx
                            bestLineText = cleanLine:gsub("\t", " | ")
                        end
                    else
                        if bestItemIdx == -1 then
                            bestItemIdx = currentItemIdx
                            bestLineText = cleanLine:gsub("\t", " | ")
                        end
                    end
                end
                
                if not isHeaderLine then
                    currentItemIdx = currentItemIdx + 1
                end
                lineIdx = lineIdx + 1
            end
            
            if bestItemIdx ~= -1 then
                sampAddChatMessage("[BPtools]: {00FF00}" .. bestLineText, 0xFFFFFFFF)
                sampSendDialogResponse(dialogId, 1, bestItemIdx, "")
                return false
            end
        end
    end
end

function imgui.OnDrawFrame()
    if window.v then
        imgui.SetNextWindowPos(imgui.ImVec2(430.0, 250.0), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSize(imgui.ImVec2(250.0, 320.0), imgui.Cond.Always)
        
        imgui.Begin(u8'BPtools (автор @krankmode)', window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
        
        if imgui.CollapsingHeader(u8'Мусорщик') then
            imgui.Checkbox(u8'Включить рендер мусорок', renderActive)
        end
        
        if imgui.CollapsingHeader(u8'Металовоз') then
            imgui.Checkbox(u8'Автоприем ближайшего вызова', metalActive)
        end
        
        if imgui.CollapsingHeader(u8'Инкассатор') then
            imgui.Checkbox(u8'Авто мини-игра', inkasatorActive)
            imgui.Checkbox(u8'2', inkasatorActive2)
        end
        
        if imgui.CollapsingHeader(u8'Окулист') then
            imgui.Checkbox(u8'Автоопределение буквы', autolActive)
        end
        
        if imgui.CollapsingHeader(u8'Пилот') then
            if vars.route.state and vars.route.name == "[AIRLS-1] Shamal.route" then
                if imgui.Button(u8'Остановить аир1лс', imgui.ImVec2(-1, 24)) then
                    vars.route.state = false
                    vars.route.name = ''
                    vars.route.packets = 0
                    if isCharInAnyCar(1) then
                        freezeCarPosition(storeCarCharIsInNoSave(1), false)
                    else
                        freezeCarPosition(1, false)
                    end
                end
            elseif not vars.route.state then
                if imgui.Button(u8'аир1лс [AIRLS-1] Shamal.route', imgui.ImVec2(-1, 24)) then
                    local filepath = getWorkingDirectory()..'\\BPtools\\[AIRLS-1] Shamal.route'
                    if not doesFileExist(filepath) then
                        sampAddChatMessage("[BPtools]: {FFFF00}Файл маршрута отсутствует. Загрузка с GitHub...", 0xFFFFFFFF)
                        downloadUrlToFile("https://raw.githubusercontent.com/decetequsub67-gif/bptools-samp/refs/heads/main/%5BAIRLS-1%5D%20Shamal.route", filepath, function(id, status, p1, p2)
                            if status == 6 then
                                sampAddChatMessage("[BPtools]: {00FF00}Маршрут успешно загружен!", 0xFFFFFFFF)
                                vars.route.state = true
                                vars.route.name = "[AIRLS-1] Shamal.route"
                                vars.route.packets = 0
                            end
                        end)
                    else
                        vars.route.state = true
                        vars.route.name = "[AIRLS-1] Shamal.route"
                        vars.route.packets = 0
                    end
                end
            end

            if vars.route.state and vars.route.name == "Air1Shamal_POSLE POSADKI.route" then
                if imgui.Button(u8'Остановить после посадки', imgui.ImVec2(-1, 24)) then
                    vars.route.state = false
                    vars.route.name = ''
                    vars.route.packets = 0
                    if isCharInAnyCar(1) then
                        freezeCarPosition(storeCarCharIsInNoSave(1), false)
                    else
                        freezeCarPosition(1, false)
                    end
                end
            elseif not vars.route.state then
                if imgui.Button(u8'после посадки [Air1Shamal_POSLE POSADKI.route]', imgui.ImVec2(-1, 24)) then
                    local filepath = getWorkingDirectory()..'\\BPtools\\Air1Shamal_POSLE POSADKI.route'
                    if not doesFileExist(filepath) then
                        sampAddChatMessage("[BPtools]: {FFFF00}Файл после посадки отсутствует. Загрузка с GitHub...", 0xFFFFFFFF)
                        downloadUrlToFile("https://raw.githubusercontent.com/decetequsub67-gif/bptools-samp/refs/heads/main/Air1Shamal_POSLE%20POSADKI.route", filepath, function(id, status, p1, p2)
                            if status == 6 then
                                sampAddChatMessage("[BPtools]: {00FF00}Маршрут после посадки загружен!", 0xFFFFFFFF)
                                vars.route.state = true
                                vars.route.name = "Air1Shamal_POSLE POSADKI.route"
                                vars.route.packets = 0
                            end
                        end)
                    else
                        vars.route.state = true
                        vars.route.name = "Air1Shamal_POSLE POSADKI.route"
                        vars.route.packets = 0
                    end
                end
            end
        end
        
        if imgui.CollapsingHeader(u8'Автобус') then
            imgui.Text(u8"Маршрут: sf6.route")
            
            if not vars.route.state then
                if imgui.Button(u8'Воспроизвести', imgui.ImVec2(-1, 24)) then
                    local filepath = getWorkingDirectory()..'\\BPtools\\sf6.route'
                    if not doesFileExist(filepath) then
                        sampAddChatMessage("[BPtools]: {FFFF00}Файл маршрута отсутствует. Загрузка с GitHub...", 0xFFFFFFFF)
                        downloadUrlToFile("https://raw.githubusercontent.com/decetequsub67-gif/bptools-samp/refs/heads/main/sf6.route", filepath, function(id, status, p1, p2)
                            if status == 6 then
                                sampAddChatMessage("[BPtools]: {00FF00}Маршрут sf6.route успешно загружен!", 0xFFFFFFFF)
                                vars.route.state = true
                                vars.route.name = "sf6.route"
                                vars.route.packets = 0
                            end
                        end)
                    else
                        vars.route.state = true
                        vars.route.name = "sf6.route"
                        vars.route.packets = 0
                    end
                end
            else
                if imgui.Button(u8'Остановить маршрут', imgui.ImVec2(-1, 24)) then
                    vars.route.state = false
                    vars.route.name = ''
                    vars.route.packets = 0
                    if isCharInAnyCar(1) then
                        freezeCarPosition(storeCarCharIsInNoSave(1), false)
                    else
                        freezeCarPosition(1, false)
                    end
                end
            end
        end

        if imgui.CollapsingHeader(u8'Обновление') then
            if imgui.Button(u8'Проверить обновление', imgui.ImVec2(-1, 24)) then
            end
            if imgui.Button(u8'Загрузить обновление', imgui.ImVec2(-1, 24)) then
            end
        end
        
        imgui.End()
    end
end

function apply_purple_transparent_style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2

    style.WindowPadding = ImVec2(15, 15)
    style.WindowRounding = 6.0
    style.FramePadding = ImVec2(5, 5)
    style.FrameRounding = 4.0
    style.ItemSpacing = ImVec2(12, 8)
    style.ItemInnerSpacing = ImVec2(8, 6)

    local text_white = ImVec4(1.00, 1.00, 1.00, 1.00)
    local bg_black_trans = ImVec4(0.06, 0.05, 0.07, 0.65)
    local purple_main = ImVec4(0.50, 0.00, 0.80, 1.00)
    local purple_hover = ImVec4(0.60, 0.10, 0.90, 1.00)
    local purple_active = ImVec4(0.40, 0.00, 0.70, 1.00)

    colors[clr.Text] = text_white
    colors[clr.WindowBg] = bg_black_trans
    colors[clr.ChildWindowBg] = bg_black_trans
    colors[clr.Border] = ImVec4(0.50, 0.00, 0.80, 0.60)
    colors[clr.FrameBg] = ImVec4(0.10, 0.05, 0.15, 0.70)
    colors[clr.FrameBgHovered] = ImVec4(0.20, 0.10, 0.30, 0.80)
    colors[clr.FrameBgActive] = ImVec4(0.30, 0.15, 0.40, 0.90)
    colors[clr.TitleBg] = ImVec4(0.10, 0.05, 0.15, 0.80)
    colors[clr.TitleBgActive] = ImVec4(0.15, 0.05, 0.25, 0.90)
    colors[clr.CheckMark] = purple_main
    colors[clr.Button] = ImVec4(0.15, 0.05, 0.25, 0.80)
    colors[clr.ButtonHovered] = purple_hover
    colors[clr.ButtonActive] = purple_active
    colors[clr.Header] = ImVec4(0.50, 0.00, 0.80, 0.40)
    colors[clr.HeaderHovered] = purple_hover
    colors[clr.HeaderActive] = purple_active
end
