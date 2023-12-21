local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

s.snode = nil
s.sname = nil

local function random_scene()

    local nodes = {}

    for i, v in pairs(runconfig.scene) do
        table.insert(nodes,i)
        if runconfig.scene[mynode] then
            table.insert(nodes,mynode)
        end
    end

    local index = math.random(1,#nodes)
    local scene_node = nodes[index]

    local scene_list = runconfig.scene[scene_node]

    index = math.random(1,#scene_list)

    local sid = scene_list[index]

    return scene_node,sid
end

--  进入游戏，随机获得一个scene
s.client.enter = function(msg)
    if s.sname then
        return {"enter",1,"已在场景"}
    end
    local snode,sid = random_scene()
    local sname = "scene"..sid

    local is_ok = s.call(snode,sname,"enter",s.id,mynode,skynet.self())

    if not is_ok then
        return {"enter",1,"进入失败"}
    end

    s.snode = snode
    s.sname = sname

    return nil
end

s.leave_scene = function()
    if not  s.sname then
        return
    end

    s.call(s.node,s.sname,"leave",s.id)

    s.snode = nil
    s.sname = nil
end

--  玩家与游戏的互动：改变移动速度（shift）
s.client.shift = function(msg)
    if not s.sname then
        return
    end

    local x = msg[2] or 0
    local y = msg[3] or 0
    s.call(s.snode,s.sname,"shift",s.id,x,y)

    return

    --local ret_msg = nil
    --if not s.sname then
    --    ret_msg = {"shift",1,"不在场景"}
    --    return ret_msg
    --    return
    --end
    --
    --
    --local is_ok = s.call(s.snode,s.sname,"shift",s.id,speed_x,speed_y)
    --
    --if not is_ok then
    --    ret_msg = {"shift",1,"更新失败"}
    --    return ret_msg
    --end
    --
    --return {"shift",0,"更新成功"}
end
