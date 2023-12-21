local skynet = require "skynet"
local runconfig = require "runconfig"
local s = require "service"

--[[
skynet 的内部时钟精度为 1/100 秒。
skynet.slepp（）将当前协程挂起1/100秒
skynet.now()
]]--

--  小球
local balls = {}

--  食物
local foods = {}

local food_max_id = 0
local food_count = 0


function ball()
    local m = {
        player_id = nil,
        node = nil,
        agent = nil,
        x = math.random(0,100),
        y = math.random(0,100),
        size = 2,
        speed_x = 0,
        speed_y = 0,
    }
    return m
end

function food()
    local m = {
        food_id = 0,
        x = math.random(0,100),
        y = math.random(0,100),
        size = 1,
    }
    return m
end




--  广播
function broadcast(msg)
    for i, v in pairs(balls) do
        s.send(v.node,v.agent,"send",msg)
    end
end

--  所有小球信息协议
local function all_ball_msg()
    local msg = {"all_ball"}
    for i,v in pairs(balls) do
        table.insert(msg,v.player_id)
        table.insert(msg,v.x)
        table.insert(msg,v.y)
        table.insert(msg,v.size)
    end
    return msg
end

--  所有食物信息协议
local function all_food_msg()
    local msg = {"all_food"}
    for k, v in pairs(foods) do
        table.insert(msg,v.food_id)
        table.insert(msg,v.x)
        table.insert(msg,v.y)
    end
    return msg
end

--  进入游戏
s.resp.enter = function(source, player_id, node,agent)
    if balls[player_id] then
       return false
    end
    local b = ball()

    b.player_id = player_id
    b.node = node
    b.agent = agent

    --  广播
    local enter_msg = {"enter", b.player_id, b.x, b.y, b.size}
    broadcast(enter_msg)

    --  记录
    balls[player_id] = b

    --  回应
    local ret_msg = {"enter",0,"进入成功"}
    s.send(b.node,b.agent,"send",ret_msg)

    --  发送战场消息（可以优化成一条）
    s.send(b.node,b.agent,"send",all_ball_msg())
    s.send(b.node,b.agent,"send",all_food_msg())

    return true
end

--  离开游戏协议
s.resp.leave = function(source, player_id)
    local ball = balls[player_id]
    if not ball then
        return false
    end

    --  玩家离线，agent通知scene，删除对应玩家的小球，并广播leave协议
    balls[player_id] = nil
    local leave_msg = {"leave",player_id}
    broadcast(leave_msg)
end

--  改变移动速度
s.resp.shift = function(source, player_id, x, y)
    local ball = balls[player_id]
    if not ball then
        return false
    end

    ball.speed_x = x
    ball.speed_y = y
    return ture
end

--  位置更新
local function move_update()
    for player_id, ball in ipairs(balls) do
        ball.x = ball.x + ball.speed_x * 0.2
        ball.y = ball.y + ball.speed_y * 0.2

        if ball.speed_y ~= 0 or ball.speed_x ~= 0 then

            local ret_msg = {"move",player_id,ball.x,ball.y}
            broadcast(ret_msg)
        end

    end
end

--  食物生成
local function food_update()
    --  食物拥有上限值50
    --  食物概率进行生成(1/50的概率)
    --  生成食物之后，食物唯一id需要进行自增
    if food_count >= 50 then
        return false
    end

    if math.random(1,100) < 98 then
        return false
    end

    food_max_id = food_max_id + 1
    food_count = food_count + 1
    local food = food()
    food.food_id = food_max_id

    foods[food_max_id] = food

    local ret_msg = {"add_food",food.food_id,food.x,food.y}

    broadcast(ret_msg)
end

--  碰撞检测
local function eat_update()
    --  暴力循环，所有小球和事务的距离
    for player_id, b in ipairs(balls) do
        for fid, f in ipairs(foods) do
            if (b.x - f.x)^2 + (b.y - f.y)^2 < b.size^2 then
                b.size = b.size + 1
                food_count = food_count - 1
                food[fid] = nil

                local ret_msg = {"eat",player_id,fid,b.size}
                broadcast(ret_msg)
            end
        end
    end
end

function update(frame)
    food_update()
    move_update()
    eat_update()
end

s.init = function()
    skynet.fork(function()
        local start_time = skynet.now()
        local frame = 0
        while true do
            frame = frame + 1
            local is_ok,err = pcall(update,frame)
            if not is_ok then
                skynet.error(err)
            end

            local end_time = skynet.now()
            local wait_time = frame * 20 - (end_time - start_time)
            if wait_time <= 0 then
                wait_time = 2
            end
            skynet.sleep(wait_time)
        end
    end)
end


--  碰撞


--  球分裂


--  排行榜

s.start(...)