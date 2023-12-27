local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local socket = require "skynet.socket"
local cjson = require "cjson"
local pb = require "protobuf"

--  映射
local conns = {}    --[fd] = conn
local players = {}  --[player_id] = gateway_player

local closed = false

function conn()
    local m = {
        fd = nil,
        player_id = nil,
    }
    return m
end

function gateway_player()
    local m = {
        player_id = nil,
        agent = nil,
        conn = nil,
    }
    return m
end

--  解包
local str_unpack = function(msg_str)
    local msg = {}

    while true do
        local arg,rest = string.match(msg_str,"(.-),(.*)")
        if arg then
            msg_str = rest
            table.insert(msg,arg)
        else
            table.insert(msg,msg_str)
            break
        end
    end

    return msg[1],msg
end

--  编包
local str_pack = function(cmd, msg)
    return table.concat(msg,",").."\r\n"
end

--  客户端发送编码后的消息，无法通过telnet直接发送
--local json_pack = function(cmd,msg)
--    local cmd_len = string.len(cmd)
--    local body = cjson.encode(msg)
--    local body_len = string.len(body)
--    local all_len = body_len + cmd_len + 2
--    local format = string.format("> i2 i2 c%d c%d",cmd_len,body_len)
--    local buff string.pack(format,all_len,cmd_len,cmd,body)
--    return buff
--end
--
--local json_unpack = function(buff_with_len)
--    local len = string.len(buff_with_len)
--    local format = string.format(">i2 c%d",len - 2)
--    local _,buff = string.unpack(format, buff_with_len)
--
--    len = string.len(buff)
--    --  netpack会自动去除首位两个字节,
--    local namelen_format = string.format("> i2 c%d", len - 2)
--    local name_len,other = string.unpack(namelen_format,buff)
--    local body_len = len - 2 - name_len
--    skynet.error("buff_len:"..len.." name_len:"..name_len.." body_len:"..body_len)
--    local body_format = string.format("> c%d c%d",name_len,body_len)
--    local cmd,body_buff = string.unpack(body_format,other)
--
--    local is_ok,msg = pcall(cjson.decode,body_buff)
--
--    if not is_ok or not msg or not msg.cmd or not cmd == msg.cmd then
--        print("json unpack error")
--        return
--    end
--    return cmd,msg
--end


local pb_pack = function(cmd,msg)
    pb.register_file("./proto/client_data.pb")
    local data = {
        cmd = cmd,
        msg = msg,
    }
    local buff = pb.encode("client_data.ClientData", data)
    print("len"..string.len(buff))
end

local pb_unpack = function(buff)
    pb.register_file("./proto/client_data.pb")
    local umsg = pb.encode("client_data.ClientData",buff)
    return umsg.cmd,umsg.msg
end

--  解决粘包
local process_msg = function(fd, msg_str)
    local cmd,msg = str_unpack(msg_str)
    skynet.error("recv "..fd.." ["..cmd.."] {"..table.concat(msg,",").."}")

    local conn = conns[fd]
    local player_id = conn.player_id

    if not player_id then
        --  登录,随机选择一个登录服务
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local login_id = math.random(1,#nodecfg.login)
        local login = "login"..login_id
        local msg = {
            id = tonumber(msg[2]),
            pw = msg[3],
        }
        pb.register_file("././proto/login.pb")
        local buff = pb.encode("login.Login",msg)

        skynet.error("send login to "..login)
        skynet.send(login,"lua","client",fd,cmd,buff)
    else
        local gplayer = players[player_id]
        local agent = gplayer.agent
        skynet.send(agent,"lua","client",cmd,msg)
    end
end

function process_buff(fd,read_buff)
    while true do
        local msg_str,rest = string.match(read_buff,"(.-)\r\n(.*)")
        if msg_str then
            read_buff = rest
            process_msg(fd,msg_str)
        else
            return read_buff
        end
    end
end

function disconnect(fd)
    --  客户端掉线
    local conn = conns[fd]
    if not conn then
        return
    end

    conn[fd] = nil

    local player_id = conn.player_id
    if not player_id then
        return
    else
        players[player_id] = nil
        local reason = "断线"
        skynet.call("agentmgr","lua","req_kick",player_id,reason)
    end
end

function rev_loop(fd)
    socket.start(fd)
    local read_buff = ""
    while true do
        local read_data = socket.read(fd)
        if read_data then
            read_buff = read_buff..read_data
            read_buff = process_buff(fd,read_buff)
        else
            skynet.error("socket close "..fd)
            disconnect(fd)
            socket.close(fd)
            return
        end
    end

end

local connect = function(fd,addr)
    if closed then
        skynet.error("gateway is shutdown")
        return
    end
    skynet.error(fd.."connect agent addr:"..addr)
    local conn = conn()
    conns[fd] = conn
    conn.fd = fd
    skynet.fork(rev_loop(fd))
end

function s.init()
    skynet.error("[gateway start]"..s.name.." "..s.id)

    --  增加socket监听
    local node = skynet.getenv("node")
    skynet.error("gate way in node ："..node.." name:"..s.name.." id:"..s.id)
    local nodecfg = runconfig[node]
    local port = nodecfg.gateway[s.id].port

    local listenfd = socket.listen("0.0.0.0",port)
    skynet.error("Listen socket :","0,0,0,0",port)

    socket.start(listenfd,connect)
end


s.start(...)


--  响应
s.resp.send_by_fd = function(source,fd,msg)
    local conn = conns[fd]
    if not conn then
        return
    end

    --local buff = str_pack(msg[1],msg)
    local buff = str_pack(msg[1],msg)
    skynet.error("send fd:"..fd.." ["..msg[1].." ] ")
    --skynet.error("send fd:"..fd.." ["..msg[1].." ] {".. table.concat(msg,",").."}")

    socket.write(fd,buff)
end

s.resp.send = function(source, player_id, msg)
    local gplayer = players[player_id]
    if not gplayer then
        return
    end

    local conn = gplayer.conn
    if not conn then
        return
    end

    local fd = conn.fd
    if not fd then
        return
    end

    s.resp.send_by_fd(source,fd,msg)
end

s.resp.sure_agent = function(source,fd, player_id, agent)
    skynet.error("[gateway success login] receive agent")
    local conn = conns[fd]
    if not conn then
        --  登录过程中下线
        skynet.call("agentmgr","lua","req_kick",player_id,"未完成登录即下线")
        return false
    end

    conn.player_id = player_id

    local gplayer = gateway_player()
    gplayer.agent = agent
    gplayer.player_id = player_id
    gplayer.conn = conn
    players[player_id] = gplayer
    return true
end

s.resp.kick = function(source,player_id)
    local gplayer = players[player_id]
    if not gplayer then
        return
    end

    local c = gplayer.conn
    players[player_id] = nil

    if not c then
        return
    end

    conns[c.fd] = nil
    disconnect(c.fd)
    socket.close(c.fd)
end

s.resp.shutdown = function(source)
    closed = true
    skynet.error("update "..s.name..s.id)
end

