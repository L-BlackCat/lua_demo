local skynet = require "skynet"
local runconfig = require "runconfig"
local skynet_manage = require "skynet.manager"

skynet.start(function()
    skynet.error("[main] start]")

    print("node:"..runconfig.agentmgr.node)

    --[[
    为什么创建服务会调init.lua的代码?
    配置中的配置了服务器启动的“service/[服务名]/init.lua作为启动文件
    --]]
    local gateway = skynet.newservice("gateway","gateway",1)
    skynet.name("gateway1",gateway)

    local login_1 = skynet.newservice("login","login",1)
    skynet.name("login1",login_1)
    local login_2 = skynet.newservice("login","login",2)
    skynet.name("login2",login_2)

    local agentmgr = skynet.newservice("agentmgr","agentmgr",0)
    skynet.name("agentmgr",agentmgr)

    local nodemgr = skynet.newservice("nodemgr","nodemgr",0)
    skynet.name("nodemgr",nodemgr)

    skynet.exit()
end)
