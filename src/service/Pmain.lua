local skynet = require "skynet"
local cjson = require "cjson"
local pb = require "protobuf"
local mysql = require "skynet.db.mysql"
local db

function test1()
    local msg = {
        _cmd = "ball_list",
        balls = {
            [1] = {id=102,x=10,y=20,size=1},
            [2] = {id=103,x=10,y=30,size=2},
        }
    }

    local buff = cjson.encode(msg)
    print(buff)
end

function test2()
    local buff = [[{"_cmd":"enter","player_id":101,"x":10,"y":20,"size":1}]]
    local isok,msg = pcall(cjson.decode,buff)
    if isok then
        print(msg._cmd)
        print(msg.player_id)
        print(msg.x)
    else
        print("err")
    end
end


function json_pack(cmd,msg)
    msg._cmd = cmd
    local body = cjson.encode(msg)
    local name_len = string.len(cmd)
    local body_len = string.len(body)
    local all_len = name_len + body_len + 2
    local format = string.format("> i2 i2 c%d c%d",name_len,body_len)
    local buff = string.pack(format,all_len,name_len,cmd,body)
    return buff
end

function json_unpack(buff)
    local len = string.len(buff)
    local namelen_format = string.format("> i2 c%d",len - 2)
    local name_len,other = string.unpack(namelen_format,buff)
    local body_len = len - 2 - name_len
    local body_format = string.format("> c%d c%d",name_len,body_len)
    local cmd,body_buff = string.unpack(body_format,other)

    local is_ok,msg = pcall(cjson.decode,body_buff)
    if not is_ok or not msg or not msg._cmd or not cmd == msg._cmd then
        print("error")
        return
    end
    return cmd,msg
end

function test3()
    local msg = {
        _cmd = "player_info",
        coin = 10,
        bag = {
            [1] = {1001,1},
            [2] = {1002,5},
        },
    }

    --  编码
    local buff_with_len = json_pack("player_info",msg)
    local len = string.len(buff_with_len)
    print("len:"..len)
    print(buff_with_len)

    --  解码
    local format = string.format(">i2 c%d",len - 2)
    local _,buff = string.unpack(format,buff_with_len)

    local cmd, umsg = json_unpack(buff)
    print("cmd:"..cmd)
    print("coin:"..tonumber(umsg.coin))
    print("sword:"..tonumber(umsg.bag[1][2]))
end

function test4()
    pb.register_file("./proto/login.pb")
    --编码
    local msg = {
        id = 101,
        pw = "123456",
    }
    local buff = pb.encode("login.Login",msg)
    print("len:"..string.len(buff))
    --解码
    local umsg = pb.decode("login.Login",buff)
    if umsg then
        print("id:"..umsg.id)
        print("pw:"..umsg.pw)
    else
        print("error")
    end
end

function test5()
    local player_data = {}
    local res = db:query("select * from user_info where player_id = 101")
    if not res or not res[1] then
        print("loading err")
        return false
    end

    player_data.coin = res[1].coin
    player_data.player_id = res[1].player_id
    player_data.name = res[1].name
    player_data.level = res[1].level
    player_data.last_login_ts = res[1].last_login_ts

    print("player_id:"..player_data.player_id)
    print("name："..player_data.name)
    print("coin："..player_data.coin)
    print("level:"..player_data.level)
    print("last_login_ts:"..player_data.last_login_ts)
end

function test6()
    pb.register_file("./storage/player_data.pb")
    --  创建角色
    local player_data = {
        player_id = 101,
        coin = 88,
        name = "tony",
        level = 10,
        last_login_time = os.time(),
    }

    local data = pb.encode("player_data.BaseInfo",player_data)
    print("data len:"..string.len(data))

    --  存入数据库
    local insert_sql = string.format("insert into u_info (player_id,data) values (%d,%s)",101,mysql.quote_sql_str(data))
    local res = db:query(insert_sql)
    if res.err then
        print("error:"..res.err)
    else
        print("OK")
    end

end

function test7()
    local res = db:query(string.format("select * from %s where player_id = %d","u_info",101))
    if not res or not res[1] then
        print("loading err")
        return false
    end

    local data = res[1].data
    pb.register_file("././storage/player_data.pb")
    local player_data = pb.decode("player_data.BaseInfo",data)

    print("player_id:"..player_data.player_id)
    print("player_coin:"..player_data.coin)
    print("player_name:"..player_data.name)
    print("player_level:"..player_data.level)
    print("player_last_login_ts:"..player_data.last_login_ts)
    print("player_skin:"..player_data.skin)
end

skynet.start(function()
    --test1()
    --test2()
    --test3()
    --
    --test4()
    db = mysql.connect({
        host = "47.103.195.188",
        port = 3306,
        database = "lua_demo",
        user = "root",
        password = "today2023",
        max_packet_size = 1024 * 1024,
        on_connect = nil,
    })

    --test5()
    --test6()
    test7()
end)
