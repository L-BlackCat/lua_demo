local skynet = require "skynet"
local socket = require "skynet.socket"
local runconfig = require "runconfig"
local s = require "service"
require "skynet.manager"

function stop_gateway()
    for node, v in pairs(runconfig.cluster) do
        for id, v in pairs(runconfig[node].gateway) do
            local name = "gateway"..id
            s.call(node,name,"shutdown")
        end
    end
end

function stop_agent()
    local node = runconfig.agentmgr.node
    while true do
        local online_num = s.call(node,"agentmgr","shutdown",5)
        if online_num <= 0 then
            return
        end
        skynet.sleep(100)
    end
end

function stop_abort()
    skynet.exit()
end


function stop()
    stop_gateway()
    stop_agent()
    --...
    stop_abort()
    return "OK"
end

local connect = function(fd,addr)
    socket.start(fd)
    socket.write(fd,"Please enter cmd\r\n")
    local cmd = socket.readline(fd,"\r\n")
    print("admin get:"..cmd)
    if cmd == "stop" then
        stop()
    else
        --...
    end
end

s.init = function ()
    local listen_fd = socket.listen("127.0.0.1",8888)
    socket.start(listen_fd,connect)
end


s.start(...)