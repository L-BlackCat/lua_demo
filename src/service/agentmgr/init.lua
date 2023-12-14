local skynet = require "skynet"
local s = require "service"

STATUS = {
    LOGIN = 2,
    GAME = 3,
    LOGOUT = 4,
}

local players = {}

function mgrplayer()
    local m ={
        player_id = nil,
        node = nil,
        agent = nil,
        status = nil,
        gate = nil,
    }
    return m
end

function s.init()
    skynet.error("[agentmgr start]")
end


s.resp.req_login = function(source,player_id,node,gate)
    skynet.error("[[agentmgr login] player_id: "..player_id)
    local mplayer = players[player_id]
    if mplayer and mplayer.status == STATUS.LOGOUT then
        skynet.error("req_login fail, at status LOGOUT "..player_id)
        return false
    end

    if mplayer and mplayer.status == LOGIN then
        skynet.error("req_login fail, at status LOGIN "..player_id)
        return false
    end

    if mplayer then
        --  顶替下线
        local pnode = mplayer.node
        local pgate = mplayer.gate
        local pagent = mplayer.agent
        mplayer.status = STATUS.LOGOUT
        s.call(pnode,pagent,"kick")
        s.send(pnode,pagent,"exit")
        --  通知agent告知客户单
        s.send(pnode,pgate,"send",player_id,{"kick","顶替下线"})
        --  通知agent关闭连接
        s.call(pnode,pgate,"kick",player_id)
    end

    --  上线
    local player = mgrplayer()
    player.player_id = player_id
    player.status = STATUS.LOGIN
    player.node = node
    player.gate = gate
    player.agent = nil
    players[player_id] = player

    local agent = s.call(node,"nodemgr","newservice","agent","agent",player_id)

    player.agent = agent
    player.status = STATUS.GAME

    return true,agent

end

s.resp.req_kick = function(source,player_id,reason)
    local mplayer = players[player_id]
    if not mplayer then
        return false
    end

    local pnode = mplayer.node
    local pagent = mplayer.agent
    local pgate = mplayer.gate
    mplayer.status = STATUS.LOGOUT

    s.call(pnode,pagent,"kick")
    s.send(pnode,pagent,"exit")
    s.call(pnode,pgate,"kick",player_id)
    players[player_id] = nil

    skynet.error("[agentmgr kick] player_id "..player_id)
    return true
end

s.start(...)