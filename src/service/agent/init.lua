local skynet = require "skynet"
local s = require "service"

s.client = {}
s.gate = nil

s.resp.client = function(source, cmd, msg)
    s.gate = source
    if s.client[cmd] then
        local ret_msg = s.client[cmd](msg,source)
        if ret_msg then
            --  s.id是agentmgr传入的player_id
            skynet.error("[agent return] ")
            skynet.send(source,"lua","send",s.id,ret_msg)
        end
    else
        skynet.error("s.resp.client fail "..cmd)
    end
end

s.init = function()
    skynet.error("[create agent] player_id.."..s.id.." load...")
    --  加载角色数据
    skynet.sleep(200)
    s.data = {
        coin = 100,
        hp = 200,
    }
end

s.start(...)

s.resp.kick = function(source)
    skynet.sleep(200)
end

s.resp.exit = function(source)
    skynet.exit()
end

s.client.work = function(msg,source)
    s.data.coin = s.data.coin + 10
    skynet.error("[agent work] "..s.data.coin)
    return {"work", s.data.coin}
end
