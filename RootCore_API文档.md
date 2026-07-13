# 懒人精灵 iOS RootCore API 接口文档

## 1. 概述

RootCore 是懒人精灵 iOS 版的核心服务组件，提供 HTTP API 接口供 Windows 客户端通信。服务基于内置的 NX HTTP Server，监听多个端口提供不同功能。

---

## 2. 端口配置

配置文件位置：`/var/mobile/Media/com.matisu.one.nxs.rootcore/work/` 下的 `userinfo.json`

```json
{
    "listenport": 5588,
    "rpcport": 12586,
    "taskport": 3333,
    "streamport": 3339,
    "kbport": 12181,
    "nxseport": 24266,
    "wdaport": 25886
}
```

| 端口 | 变量名 | 用途 | 协议 |
|------|--------|------|------|
| **5588** | listenport | 主 HTTP 监听端口（API 入口） | HTTP |
| **12586** | rpcport | RPC 通信端口（TQPeer Protobuf） | TCP |
| **3333** | taskport | 任务执行端口 | TCP |
| **3339** | streamport | 流媒体/屏幕传输端口 | TCP |
| **12181** | kbport | 键盘输入端口 | TCP |
| **24266** | nxseport | NX 服务端口 | TCP |
| **25886** | wdaport | WebDAV 端口 | HTTP |

### 连接方式

```
Windows 客户端 ──→ 192.69.0.99:5588 (HTTP API)
                    ├── /api/installsc
                    ├── /api/liveport
                    ├── /api/info
                    ├── /api/command
                    ├── /api/screenshot
                    ├── /api/upload
                    ├── /api/download
                    └── /api/health
```

---

## 3. API 端点详细说明

### 3.1 `/api/installsc` — 安装脚本

**用途：** 从 Windows 客户端下发加密的 Lua 脚本（.lrj 文件）到 iOS 设备

**方法：** POST

**请求：**
```
POST http://192.69.0.99:5588/api/installsc
Content-Type: application/octet-stream
Body: <script.lrj 文件二进制内容>
```

**响应：**
```json
{
    "success": true,
    "message": "Script installed"
}
```

**lrj 文件格式：** ZIP 压缩包，包含以下结构：
```
script.lrj (ZIP)
├── 脚本/Matisu.lua          # 入口脚本（加密）
├── 脚本/MTHS.lua            # 核心库（加密）
├── 插件/自定义库.lua         # 自定义库（加密）
├── 资源/Matisu.rc           # 资源配置
├── 界面/Matisu.ui           # UI 定义
├── 界面/index.html          # 控制 Web UI
├── config                   # 二进制配置
├── entry.json               # 入口点定义
└── version                  # 版本号
```

**entry.json 示例：**
```json
{
    "lc_entry": "脚本/Matisu.lua",
    "plugin_entry": "插件",
    "rc_entry": "资源/Matisu.rc",
    "ui_entry": "界面/Matisu.ui"
}
```

**使用流程：**
```
1. Windows 端加密 Lua 源码
2. 打包为 script.lrj (ZIP)
3. POST 到 /api/installsc
4. iOS 端接收并保存
5. RootCore 解密并加载执行
```

---

### 3.2 `/api/liveport` — 实时端口

**用途：** 获取或设置实时通信端口

**方法：** GET / POST

**请求：**
```
GET http://192.69.0.99:5588/api/liveport
```

**响应：**
```json
{
    "port": 3339
}
```

---

### 3.3 `/api/info` — 设备信息

**用途：** 获取设备和应用信息

**方法：** GET

**请求：**
```
GET http://192.69.0.99:5588/api/info
```

**响应：**
```json
{
    "status": "running",
    "httpPort": 5588,
    "deviceName": "iPhone",
    "deviceId": "xxx",
    "version": "1.0.0",
    "uptime": "0s"
}
```

---

### 3.4 `/api/command` — 命令执行

**用途：** 发送命令到 RootCore 执行

**方法：** POST

**请求：**
```
POST http://192.69.0.99:5588/api/command
Content-Type: application/json
Body: {
    "command": "startscript",
    "params": {}
}
```

**支持的命令：**
| 命令 | 说明 |
|------|------|
| `startscript` | 启动脚本 |
| `stopscript` | 停止脚本 |
| `checkrun` | 检查运行状态 |
| `runscript` | 运行脚本 |
| `screencap` | 截图 |
| `bindcard` | 绑定卡片 |
| `click` | 点击 |
| `keypress` | 按键 |
| `swipe` | 滑动 |
| `sendtext` | 发送文本 |
| `openfile` | 打开文件 |
| `restartservice` | 重启服务 |
| `frontappname` | 获取前台应用名 |
| `getdeviceid` | 获取设备ID |
| `getscreeninfo` | 获取屏幕信息 |
| `getscriptversion` | 获取脚本版本 |
| `runapp` | 运行应用 |

**响应：**
```json
{
    "success": true,
    "result": "..."
}
```

---

### 3.5 `/api/screenshot` — 截图

**用途：** 获取设备屏幕截图

**方法：** GET

**请求：**
```
GET http://192.69.0.99:5588/api/screenshot
```

**响应：** PNG 图片二进制数据

**原始截图：**
```
GET http://192.69.0.99:5588/api/screenshot/raw
```

**响应：** 原始帧数据

---

### 3.6 `/api/upload` — 上传文件

**用途：** 上传文件到设备

**方法：** POST

**请求：**
```
POST http://192.69.0.99:5588/api/upload?path=/var/mobile/Media/filename.ext
Content-Type: application/octet-stream
Body: <文件二进制内容>
```

**响应：**
```json
{
    "success": true,
    "path": "/var/mobile/Media/filename.ext",
    "size": 12345,
    "download_url": "/api/download/file/filename.ext"
}
```

---

### 3.7 `/api/download/list` — 文件列表

**用途：** 列出可下载的文件

**方法：** GET

**请求：**
```
GET http://192.69.0.99:5588/api/download/list
GET http://192.69.0.99:5588/api/download/list?subdir=subfolder
```

**响应：**
```json
{
    "files": [
        {
            "name": "file.txt",
            "size": 1234,
            "size_formatted": "1.2 KB",
            "created_at": "2024-01-01T00:00:00Z",
            "modified_at": "2024-01-01T00:00:00Z"
        }
    ]
}
```

---

### 3.8 `/api/download/file/(.*)` — 下载文件

**用途：** 下载指定文件

**方法：** GET

**请求：**
```
GET http://192.69.0.99:5588/api/download/file/filename.txt
```

**响应：** 文件二进制数据

---

### 3.9 `/api/data` — 数据接口

**用途：** 数据读写

**方法：** GET / POST

---

### 3.10 `/api/health` — 健康检查

**用途：** 检查服务是否正常运行

**方法：** GET

**请求：**
```
GET http://192.69.0.99:5588/api/health
```

**响应：**
```json
{
    "status": "ok",
    "healthy": true
}
```

---

## 4. 通信协议

### 4.1 HTTP API (端口 5588)

用于文件传输、截图、命令执行等操作。

### 4.2 TQPeer RPC (端口 12586)

基于 Protobuf 的 RPC 通信系统，用于实时控制。

**握手流程：**
```
Windows 客户端                    iOS RootCore
      │                              │
      │  TCP 连接 12586              │
      │  ─────────────────────────→  │
      │                              │
      │  RPC_LOGIN 握手              │
      │  ─────────────────────────→  │
      │                              │
      │  ←─────── 欢迎验证           │
      │                              │
      │  开始 RPC 通信               │
      │  ←─────────────────────────→ │
```

### 4.3 Task 端口 (3333)

用于任务执行和状态同步。

### 4.4 Stream 端口 (3339)

用于屏幕流传输（VNC/屏幕镜像）。

---

## 5. 文件系统路径

### 5.1 应用目录

```
/private/var/containers/Bundle/Application/
└── 20A5860D-5C29-473E-95C6-2CE382FFE75C/
    └── RootService.app/
        ├── RootService          # 主服务二进制
        ├── nxsign               # 代码签名工具
        ├── Info.plist
        ├── userinfo.json
        ├── Root/
        │   ├── RootCore         # Lua 引擎二进制
        │   ├── RootCore.bak     # 原版备份
        │   ├── keys.txt         # 字符替换表
        │   ├── lua.zip          # Lua 网络库
        │   ├── script.lrj       # 加密脚本包
        │   ├── userinfo.json    # 端口配置
        │   └── Frameworks/
        │       ├── libengine.dylib      # Lua 引擎 + 加密库
        │       ├── LuaDumper.dylib      # (可选) 字节码 dump 工具
        │       └── onnxruntime.framework/ # ONNX 推理框架
        └── Watchdog/
            └── RootWatchdog     # 看门狗进程
```

### 5.2 数据目录

```
/var/mobile/Media/
├── com.matisu.one.nxs.rootcore/
│   ├── work/                    # 工作目录
│   │   ├── sklrjx.txt          # 任务队列
│   │   └── wodefuwuqi.txt      # 服务器缓存
│   ├── sys/                     # 系统配置
│   ├── paddle/                  # 配置数据
│   ├── logdir/                  # 日志目录
│   └── script/                  # 脚本目录
├── Matisu/
│   ├── script.lrj               # 脚本包
│   ├── M_fuwuduan.txt           # 服务端配置
│   └── M_shuju.txt              # 数据文件
└── log.txt                      # 服务日志
```

---

## 6. 服务启动流程

```
1. RootService.app 启动
   │
2. RootService 加载 RootCore
   │  execPath: .../RootService.app/Root/RootCore
   │
3. RootCore 加载 Frameworks
   │  ├── onnxruntime.framework (ML 推理)
   │  └── libengine.dylib (Lua 引擎 + 加密)
   │
4. 获取函数指针 (dlsym)
   │  startService, stopScript, startScript
   │  obtainMsg, sendUI, freeMem, sendCmd
   │
5. 设置回调
   │  setSignDylibCallback (代码签名)
   │  setDlopenExCallback (动态库加载)
   │  setNativeServiceAPI (原生服务 API)
   │
6. startService() 启动服务
   │  返回: 0 (成功)
   │
7. loadLuaEngine() 加载 Lua 引擎
   │
8. 监听端口
   ├── 5588 (HTTP API)
   ├── 3333 (Task)
   ├── 3339 (Stream)
   └── 24266 (NX Service)
```

---

## 7. 错误处理

### 常见错误

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| 启动服务失败，请检查端口设置 | 端口被占用或服务未启动 | 重启设备和应用 |
| Connection refused | 服务未监听端口 | 等待服务完全启动 |
| Authentication failed | 密码错误 | 检查 SSH 密码 |
| Permission denied | 权限不足 | 使用 sudo |

### 日志查看

```bash
# 通过 SSH 查看日志
ssh mobile@192.69.0.99
sudo cat /var/mobile/Media/log.txt

# 查看最新日志
sudo tail -50 /var/mobile/Media/log.txt
```

---

## 8. 安全说明

- 服务使用 ad-hoc 签名（无 Apple Developer 证书）
- 加密使用 AES 算法 (OpenSSL EVP API)
- 密钥通过 `aes_keygen` 函数生成
- 支持 AES-128/192/256，CBC/CTR/ECB 模式
- IV 长度 16 字节

---

*文档版本: 1.0*
*基于 RootCore 二进制分析*
