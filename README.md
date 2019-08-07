# meiru(美茹)
meiru是一个功能强大，同时支持10万链接，并且业务逻辑支持并发的web框架。
基于游戏skynet框架开发。同时支持http/https和ws/wss业务。
它与node的express框架做参考。

## 优势特点
与express相比，具有如下优势：
1. 业务层支持多核并发，轻松应对性能瓶颈。极易使用多核和建立集群
2. 组件设计，路由层通过node树组成，不与任何业务相关。业务层通过组件实现。可以随意开发自己的组件。
3. 已内置markdown解析器和elua的html模板，轻松实现类似express的ejs渲染
4. 使用lua协程，避免有任何回调函数，让代码优美简洁。（node到处都是回调函数）
5. 无性能瓶颈，底层使用C语言实现，最大限度发挥硬件的能力。json等大量消耗计算的模块使用c实现。
6. 依托于skynet，拥有强大的稳定性和容错能力。只要内存不满，skynet可以持续运行数年而不会进程闪退。
7. meiru设计了多个调试工具，让你轻松分析错误。
8. lua是一门简单的嵌入式语言，加上使用简单的skynet，大幅降低开发门槛。

## 快速使用
1. 下载源代码，或者使用git克隆
```
git clone https://github.com/skynetlua/meiru-skynet.git
```

2. 创建工程
以创建test项目为例，在终端，cd到meiru-skynet目录下。执行
```
./meiru/bin/meiru create test
```
可以把meiru-skynet/meiru/bin添加到系统环境变量
```
meiru create test
```

3. 启动工程
```
./meiru/bin/meiru start test
```
浏览器打开127.0.0.1:8080/index。既可以看到结果

4. 停止服务
```
./meiru/bin/meiru stop test
```


test项目的结构如下
```
assets //存放资源
config //启动这个项目的配置文件
lua //存放lua脚本库文件
```

###配置文件介绍

```
--导入meiru的配置表文件
include "../../meiru/config/config.main"

----------------------------------------------------
--test项目配置
----------------------------------------------------
test_path = projects_path .. "test/"
lua_path  = lua_path .. test_path .. "lua/?.lua;"

--开启测试模式
debug = 1
--http回调文件
service_http = "app"
http_port    = 8080
service_num  = 1
```


## skyent框架介绍
软件是充分利用硬件资源，方便满足各种计算业务的需求。在服务器领域，计算机需要提供网络通信、数据存储和计算。
对于后端框架，也就提供这两方面的能力，尽可能地提高网络连接数和数据吞吐量，尽可能地使用内存和CPU。
由于后端需要连接众多的客户端，导致业务量很大，如果框架设计不合理，程序随时都可能因为内存爆满而被系统kill掉，或者CPU应付不过来堵掉。
类似交通规则一样，我们需要设计一种业务规则，让计算机发挥最大的能力。skynet框架就是处理这些问题的交通规则了。

现在的主机CPU都是多核，一个CPU核只能计算一个业务，在程序中，与一条线程对应。而需要计算的业务数量却是非常的巨大。
skynet就把一条线程当成一个worker工人。把一种计算业务当成一个service服务。然后把各种计算业务分配给各个service。
哪个worker线程空闲，就把这个service服务派发给它处理。有时候，service之间需要交换数据，可通过消息传递实现。
这个就是skynet运作方式。它是使用C语言实现，效率非常高。

skynet使用C语言实现了这个交通规则，让计算业务井然有序，让程序开发避免遇到多线程混乱的局面。但是，它使用C语言开发，使用起来非常不方便。
比如，C语言容易发生内存问题，一遇错误，程序就会崩溃，每次修改代码需要编译，构建麻烦。对技术人员要求很高。所以，需要嵌入一种脚本语言来解决这种问题。
skynet的service服务之间是独立，它们仅仅是通过消息交流数据，它们的数量可以非常多，开启100个service也是正常的。
我们希望一个service一个脚本虚拟机vm，如果只有一个虚拟机vm，那么在脚本层必然会引入了多线程的问题。好不容易在C底层解决了多线程的问题，却在脚本层搞回去了，这不是想要的。

因此得出，这个嵌入脚本需要单线程执行，而且vm非常小。不然跑100个vm，需要消耗巨大内存。所以，skynet选择了lua，一个lua的vm也就几百kb大小。
在skynet，可以开发各种的service，把lua文件保存在service目录。通过给定文件名，通过skynet.newservice("服务文件名称")就可以启动它。
然后把其他共享的lua文件保存到lualib上。方便各个service的mv可以共享使用。
剩下的就是lua开发相关的事情。lua自带协程，解决了nodejs到处都是回调函数的弊端。

skynet也提供了cluster模块，让你轻轻建立一个服务器集群。同时，skynet的生态不断建立，mysql、redis和monogo等基层功能也有。最近加了对https的支持，基本满足游戏后端开发的需求。
但是，缺乏对web开发支持。这就是meiru框架所要解决的问题。

## meiru框架介绍

### web业务处理机制
meiru框架是用lua开发的mini框架，它只是提供web业务请求处理，无任何依赖。但是它要对外提供服务需要寄生在skynet上。skynet提供了网络支持，meiru解决web业务。
meiru框架引入组件设计，把具体业务丢给组件处理。构建一棵node树，node节点携带path参数，然后用组件填充，实现功能。
meiru默认自带的node树如下：
```
node_root(树根)
++node_req(处理请求节点)
++++node_start(开始节点)
----ComInit(初始化组件)
----ComPath(处理url组件)
----ComHeader(处理http头部组件)
----ComSession(处理http的cookie和session组件)
++++++node_static:/public(处理静态资源节点)
------ComStatic(处理静态资源组件)
++++++node_routers(路由器节点)
------ComBody(处理http的body组件)
------ComCSRF(处理csrf组件组件)
++++++++node_router:/index(路由/index节点)
--------ComHandle(处理http/xxx.xx.xx/index业务组件)
++++node_finish(结束节点)
----ComFinish(结束组件)

++node_res(处理返回节点)
--ComRender(渲染html组件)
--ComResponse(发送给客户端组件)

```

路由功能由node实现，node节点携带path参数，req请求过程从node_req树根开始，依次判断req.path是否等于该节点node的path值。
如果符合，就调用该节点携带的组件。如果组件或者节点需要返回，return一个非nil值。就停止迭代退出。
然后进入到返回树根node_res，返回http请求。


### 网络数据处理机制
这是一个管理学的问题。就像一座工厂，怎样把各个工作分配给不同的工人，现实流水作业，获得最大的效益。

meiru的逻辑很简单。指定一个meiru/serverd服务，监听客户端连接。然后创建指定数量的meiru/agentd服务。
meiru/serverd监听到连接以后，根据一定规则选择某一个agentd，把连接派发给它,agentd接到这个连接就开启连接客户端，与客户端通信。
由于agentd服务需要快速处理业务，不能有任何io阻塞。需要创建一组filed文件服务用于读取文件(小于5MB的文件)，文件内容读好后，再通知agentd服务。
agentd服务再把数据发送给客户端。在filed文件服务中，文件数据是存储在stm结构中，保证只有一份数据。

### 工程结构
一个meiru工程是通过项目来组织的。每个项目可以作为一个独立进程运行。一个项目可以配置多种模式。
可以通过每个项目的config配置文件看出来。`工程文件夹workspace/项目名/config/config.模式名`
，其中meiru文件夹是根项目

例如，创建一个服务器集群。集群结构如下，1个登录服，3个游戏服，3个战斗服，一个压力测试服，一个web后台服。
工程文件结构设计如下：
```
/meiru(根项目)
/game(游戏项目)
/game/config/config.login
/game/config/config.game
/game/config/config.fight
/web(web项目)
/web/config/config.web
/test(测试项目)
/test/config/config.test
```
运行各个服务器。(上述服务器集群，只要端口不冲突，可以运行在同一台主机上，也可运行在不同服务器上。它们之间通信通过cluster模块非常容易现实)
在终端cd到工程目录。
然后执行下面命令，即可启动。
```
./meiru/skynet/skynet ./项目名/config/config.模式名
```
meiru也提供一个快捷工具，可以快速启动
命令格式：
```
./meiru/bin/meiru 项目名/config/config.模式名
```
或者
```
./meiru/bin/meiru start 项目名 [模式名]
```

如果只有一个项目，这个项目只有一个模式。直接运行`./meiru/bin/meiru start`
如果项目名和模式名相同。直接运行`./meiru/bin/meiru start 项目名`

停服，meiru也提供相关工具
命令格式
```
./meiru/bin/meiru stop 项目名 [模式名]
```
如果只有一个项目，这个项目只有一个模式，直接运行`./meiru/bin/meiru stop`

### 项目结构
在meiru源代码目录，有两个文件夹meiru和test，表示有两个项目，meiru是根项目，创建的test项目

test项目的结构如下
```
assets //存放相关资源
config //启动这个项目的配置文件
lualib //存放lua脚本库文件
service //存放启动服务脚本文件
```
导入其他项目是通过导入它的项目的配置文件`./项目名/config/config.模式名`来实现

**例子**
meiru是根项目，test需要导入meiru项目。需要在配置文件`test/config/config.common`导入
```
include "../../meiru/config/config.header"
```
配置文件是一个lua文件，字段只支持string和数字等。
在程序中可以通过`local xxx = skynet.getenv("xxx")`读取它的值。

在test项目中。需要运行多种模式。所以这个项目的共用配置抽出变成config.common。其他子模式通过include "config.common"导入。

在配置文件中，必须配置
test_path = projects_path .. "test/"
lua_path   = lua_path .. test_path .. "lualib/?.lua;"
luaservice = luaservice .. test_path .. "service/?.lua;"
必须把该项目的lua脚本文件导入到lua中，lua才能读取到它。
其中lua_path和luaservice是lua的环境变量

### 服务调用示例
通过meiru/serverd服务启动
```
	--创建meiru/serverd服务
	local httpd = skynet.newservice("meiru/serverd")

	--指定启动参数
    local param = {
        port = skynet.getenv("httpport"), --(不指定端口，就默认80端口)
        services = {          --(指定服务类型，及其对应的回调文件(共四种http/https/ws/wss))
            ['http'] = "web", 
        },
        instance = 4, --(启动agentd服务个数 CPU核数的2倍)
    }
    --发消息，让meiru/serverd服务监听端口，启动四个agentd服务。每个agentd服务会加载lua文件`项目名/lualib/web.lua`,
    skynet.call(httpd, "lua", "start", param)
```

services参数配置有四种方式，有两组搭配
services = {
	['http'] = "web", 
	['ws'] = "ws", 
}
services = {
	['https'] = "web", 
	['wss'] = "ws", 
}
两组不能混合。
也就是开启了http模式，不能同时指定https模式
web表示回调文件`项目名/lualib/web.lua`
ws表示回调文件`项目名/lualib/ws.lua`

回调文件需要支持这个接口
```
local ws = {}
function ws.dispatch(req, res)
end
return ws
```
尽管http和websocket是同一端口80，agentd服务会自动判断请求模式，确定是http请求还是websocket
如果是http请求，就会调用`['http'] = "web"` 指定的文件。
如果是websocket，就会调用`['ws'] = "ws"` 指定的文件。

