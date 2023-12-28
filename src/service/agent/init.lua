local skynet = require "skynet"
local s = require "service"

s.client = {}
s.gate = nil

require "scene"

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

local last_check_ts = 1703462400
--  定时唤醒。周一早8点30分
function get_week_day_830(timestamp)
    local day = (timestamp + 8 * 3600 + 3 * 24 * 3600 - 8 * 3600 - 30 * 60) / (3600 * 24 *7)
    return math.ceil(day)
end

function first_login_week()
    skynet.error("first login week "..s.name..s.id)
end

function open_activity()
    print(">>>open activity")
end

function timer()
    local last_week = get_week_day_830(last_check_ts)
    local now = os.time()
    local week = get_week_day_830(now)
    last_check_ts = now
    if week > last_week then
        open_activity()
    end
end

--  每天5点刷新
function get_day(timestamp)
    local day = (timestamp + 8 * 3600 - 5 * 3600) / (24 * 3600)
    return math.ceil(day)
end


function first_login_day()
    skynet.error("first login day")
end


s.init = function()
    skynet.error("[create agent] player_id.."..s.id.." load...")
    --  加载角色数据
    skynet.sleep(200)
    s.data = {
        coin = 100,
        last_login_ts = 1703624400;
    }


    local last_day = get_day(s.data.last_login_ts)
    local day = get_day(os.time())

    if day > last_day then
        first_login_day()
    end

    skynet.fork(function()
        while true do
            local is_ok,err = pcall(timer)
            if not is_ok then
                skynet.error(err)
            end

            skynet.sleep(1000)
        end
    end)

end

s.start(...)


s.resp.kick = function(source)
    s.leave_scene()
    --  保存玩家数据
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

s.resp.send = function(source,msg)
    skynet.send(s.gate,"lua","send",s.id,msg)
    --skynet.error("agent send cmd:"..msg[1]" gate"..s.gate)
end