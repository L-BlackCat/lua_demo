local skynet = require "skynet"
local runconfig = require "runconfig"
local skynet_manage = require "skynet.manager"
local cluster = require "skynet.cluster"

skynet.start(function()
    skynet.error("[main] start]")

    print("node:"..runconfig.agentmgr.node)

    --[[
    为什么创建服务会调init.lua的代码?
    配置中的配置了服务器启动的“service/[服务名]/init.lua作为启动文件
    --]]
    --local gateway = skynet.newservice("gateway","gateway",1)
    --skynet.name("gateway1",gateway)
    --
    --local login_1 = skynet.newservice("login","login",1)
    --skynet.name("login1",login_1)
    --local login_2 = skynet.newservice("login","login",2)
    --skynet.name("login2",login_2)
    --
    --local agentmgr = skynet.newservice("agentmgr","agentmgr",0)
    --skynet.name("agentmgr",agentmgr)
    --
    --local nodemgr = skynet.newservice("nodemgr","nodemgr",0)
    --skynet.name("nodemgr",nodemgr)


    --  初始化
    local mynode = skynet.getenv("node")
    local nodecfg = runconfig[mynode]

    --  节点管理
    local nodemgr = skynet.newservice("nodemgr","nodemgr",0)
    skynet.name("nodemgr",nodemgr)

    --  集群
    --  本节点加载集群各节点地址
    cluster.reload(runconfig.cluster)
    --  启动节点
    cluster.open(mynode)

    --  gateway
    for i, v in pairs(nodecfg.gateway or {}) do
        local src = skynet.newservice("gateway","gateway",i)
        skynet.name("gateway"..i,src)
    end

    --  login
    for i,v in pairs(nodecfg.login or {}) do
        local src = skynet.newservice("login","login",i)
        skynet.name("login"..i,src)
    end

    --agentmgr
    local anode = runconfig.agentmgr.node
    if anode == mynode then
        local srv = skynet.newservice("agentmgr","agentmgr",0)
        skynet.name("agentmgr",srv)
    else
        local proxy = cluster.proxy(anode,"agentmgr")
        skynet.name("agentmgr",proxy)
    end

    --  开启scene服务
    for _, sid in pairs(runconfig.scene[mynode] or {}) do
        local srv = skynet.newservice("scene","scene",sid)
        skynet.name("scene"..sid,srv)
    end

    skynet.exit()
end)
