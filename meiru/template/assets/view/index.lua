
<div id="content">
    <div class="panel">
        <% if topics and #topics > 0 then %>
            <div class="inner no-padding">
                <%- partial('item', {collection = topics, as = 'topic'}) %>
            </div>
        <% else %>
            <div class="inner">
                <p>无话题</p>
            </div>
        <% end %>
    </div>
    <%- markdown([[
        ## 快速使用
推荐在centos7系统运行
目前适配的系统：centos7,ubuntu。其他系统尚未适配过。

centos7安装git工具
```
sudo yum install -y git
```
ubuntu安装git工具
```
sudo apt-get install -y git
```

### 1. 下载源代码，或者使用git克隆
```
git clone https://github.com/skynetlua/meiru-skynet.git
```

### 2. 配置工程
```
cd yourfolder/meiru-skynet
./meiru/bin/meiru setup
```
meiru setup会自动下载安装gcc，autoconf，readline，openssl等。

### 3. 编译工程
```
./meiru/bin/meiru build
```
该命令会自动进行编译。编译后，生成skynet程序，就可以在其他主机运行，而无需要再次编译。
如果要清理编译文件，可执行
```
./meiru/bin/meiru clean
```

### 4. 创建工程
以创建test项目为例，在终端，cd到meiru-skynet目录下。执行
```
./meiru/bin/meiru create test
```
可以把meiru-skynet/meiru/bin添加到系统环境变量
```
meiru create test
```

### 5. 启动工程
```
./meiru/bin/meiru start test
```
浏览器打开127.0.0.1:8080/index。既可以看到结果

### 6. 停止服务
```
./meiru/bin/meiru stop test
```


test项目的结构如下
```
assets //存放资源
config //项目的启动配置文件
lualib //存放lua脚本库文件
```
]]) %>
</div>
