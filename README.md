# meiru(美茹)
meiru是一个功能强大，同时支持10万链接，业务逻辑并发支持的web框架。
基于游戏skynet框架开发。同时支持http/https和ws/wss服务。
它与node的express框架做参考。

## 优势特点
与express相比，具有如下优势：
1. 业务层支持多核并发，轻松应对性能瓶颈。使用多核和建立集群
2. 组件设计，路由层通过node树组成，不与任何业务相关。业务层通过组件实现。可以随意开发自己的组件。
3. 已内置markdown解析器和elua的html模板，轻松实现类似的express的渲染
4. 使用lua协程，避免有任何回调函数，让代码优美简洁。（node到处都是回调函数）
5. 无性能瓶颈，底层使用C语言实现，最大限度发挥硬件的能力。json等大量消耗计算的模块使用c实现。
6. 依托于skynet，拥有强大的稳定性和容错能力。只要内存不满，skynet可以持续运行数年而不会进程闪退。
7. meiru设计了多个调试工具，让你轻松分析错误。


## skyent框架介绍
软件是充分利用硬件资源，方便满足各种计算业务。在服务器领域，计算机需要提供网络通信、数据存储和计算。
对于后端框架，也就提供这两方面的能力，尽可能地提高网络连接数和数据吞吐量，尽可能地使用内存和CPU。
由于后端需要连接众多的客户端，导致业务量很大，如果框架设计不合理，程序随时都可能因为内存爆满而被系统kill掉，或者CPU应付不过来堵掉。
类似交通规则一样，我们需要设计一种业务规则，让计算机发挥最大的能力。这个交通规则就是skynet框架了。

现在的主机CPU都是多核，一个CPU核只能计算一个业务，在程序中，与一条线程对应。而需要计算业务数量却是非常的巨大。
skynet就把一条线程当成一个worker工人。把一种计算业务当成一个service服务。然后把各种计算业务分配给各个service。
哪个worker线程空闲，就把这个service服务派发给它处理。有时候，service之间需要交换数据，可通过消息传递实现。
这个就是skynet运作方式。它是使用C语言实现，效率非常高。

skynet使用C语言实现了这个交通规则，让计算业务井然有序，让程序开发避免遇到多线程混乱的局面。但是，它使用C语言开发，使用起来非常不方便。
比如，C语言容易发生内存问题，一遇错误，程序就会崩溃，每次修改代码需要编译，构建麻烦。对技术人员要求很高。所以，需要嵌入一种脚本语言来解决这种问题。
skynet的service服务之间是独立，它们仅仅是通过消息交流数据，它们的数量非常多，100个service也算正常。
我们希望一个service一个脚本虚拟机vm，如果只有一个虚拟机vm，那么在脚本层必然会引入了多线程的问题。好不容易在C底层解决了多线程的问题，却在脚本层搞回去了，这不是想要的。

因此得出，这个嵌入脚本需要单线程执行，而且vm非常小。不然跑100个vm，需要消耗巨大内存的。所以，skynet选择了lua。
在skynet，可以开发各种的service，把lua文件保存在service目录。通过给定文件名，通过skynet.newservice("服务文件名称")就可以启动它。
然后把其他共享的lua文件保存到lualib上。方便各个service的mv可以共享使用。
剩下的就是lua开发相关的事情。lua自带协程，解决了nodejs到处都是回调函数的弊端。

skynet也提供了cluster模块，让你轻轻建立一个服务器集群。同时，skynet的生态不断建立，mysql、redis和monogo等基层功能也有。最近加了对https的支持，基本满足游戏后端开发的需求。

但是，对web支持，远远不够的。这就是meiru框架所要解决的问题。






## meiru框架介绍

### web业务处理机制
meiru框架是建立在skynet基础上。引入组件设计，把具体业务丢给组件处理。构建一棵node树，node节点携带path参数，然后用组件填充，实现功能。
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

meiru的逻辑很简单。指定一个serverd服务，监听客户端连接。然后创建CPU核数的2-3倍数量的agentd服务。
serverd监听到连接以后，根据一定规则选择某一个agentd，把连接派发给它,agentd接到这个连接就开启连接客户端，与客户端通信。
由于agentd服务需要快速处理业务，不能有任何io阻塞。需要创建一组filed文件服务用于读取文件(小于5MB的文件)，文件内容读好后，再通知agentd服务。
agentd服务再发数据发送给客户端。


### 工程结构
一个meiru工程是通过项目来组织的。每个项目可以作为一个进程独立运行。一个项目可以配置多种模式。
可以通过每个项目的config配置文件看出来。`工程文件夹/项目名/config/config.模式名`

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
meiru也提供一个工具，可以快速启动
命令格式：
```
./meiru/bin/meiru  项目名/config/config.模式名
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


### 启动
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



## 新手引导
1. 系统环境
meiru依托skynet，暂时支持linux，macox和Unix等非window系统
meiru默认编译好的程序，是centos程序。其他平台需要重新编译
2. 安装
直接下载源代码，即可。或使用使用git clone下载。
3. 创建工程和test项目
创建工程文件夹。把上述里面的meiru文件夹拷贝进来。
在工程文件夹下，创建test文件（即test项目）

test项目的结构如下
```
assets //存放相关资源
config //启动这个项目的配置文件
lualib //存放lua脚本库文件
service //存放启动服务脚本文件
```

4. 创建main服务。
在service文件夹，创建main.lua。作为启动服务
文件内容
```
local skynet = require "skynet.manager"
local filed = require "meiru.lib.filed"
skynet.start(function()
	--启动时，创建文件filed服务
    filed.init()
    --创建http/ws服务，
    local httpd = skynet.newservice("meiru/serverd")
    local param = {
        port = skynet.getenv("httpport"), --(不指定端口，就默认80端口)
        services = {
            ['http'] = "web", 
        },
        instance = 4,
    }
    skynet.call(httpd, "lua", "start", param)
end)
```
