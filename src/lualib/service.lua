local skynet = require "skynet"
local cluster = require "skynet.cluster"

local M = {
    name = "",
    id = 0,

    exit=nil,
    init=nil,

    resp={}
}


function traceback(err)
    skynet.error(tostring(error()))
    skynet.error(debug.traceback())
end

--  接受消息
local dispatch = function(session, source, cmd, ...)
    local fun = M.resp[cmd]
    if not fun then
        skynet.ret()
        return
    end

    --  安全调用fun方法，如果fun方法报错，程序不会中断，而会把消息移交给第二个参数的traceback。
    --  如果程序报错xpcall会返回false；正常执行，第一个参数是true，第二个参数开始才是fun的返回值。
    --  xpcall会把第3个及后面的参数传给fun，即fun的第一个参数是source，第二个参数是可变参数“...”。
    local ret = table.pack(xpcall(fun,traceback,source,...))

    local isOk = ret[1]

    if not isOk then
        skynet.ret()
        return
    end

    --  fun方法的真正返回值从ret[2]开始，用table.unpack解出ret[2]、ret[3]...，并返回给发送方
    skynet.retpack(table.unpack(ret,2))
end

function init()
    skynet.dispatch("lua", dispatch)

    if M.init then
        M.init()
    end
end

function M.start(name, id, ...)
    M.name = name;
    M.id = tonumber(id);
    skynet.start(init)
end





--  发送消息
function M.call(node,srv,...)
    local mynode = skynet.getenv("node")

    if mynode == node then
        return skynet.call(srv,"lua",...)
    else
        return cluster.call(node,srv,...)
    end
end

function M.send(node,srv,...)
    local mynode = skynet.getenv("node")

    if mynode == node then
        return skynet.send(srv,"lua",...)
    else
        return cluster.send(node,srv,...)
    end
end
return M
