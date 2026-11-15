# 架构与原理

> ⚠️ **本文档部分内容已被 [`08-verification.md`](08-verification.md) 推翻。**
> 特别是 `enable_lan_only` 这个配置键**不存在**，端口也不是 2456。
> 阅读时请对照 08 号文档的修正说明。

## 为什么不能"一份游戏两台机同时在线"

Steam 的限制在账户层，不在游戏层：

- 同一个 Steam 账号，同一款游戏，同一时间只允许一个实例运行
- 家庭共享：同一款游戏同时只能一人启动，且共享者本人也受限制
- 离线模式：需要先在线验证，验证后并发限制依然生效

所以走 Steam 官方通道，一份授权在物理上只能一个人玩。

## 突破口在哪

Valheim 的联机有两个可分离的部分：

1. **身份认证**：客户端向服务端证明"我是合法玩家"——这一步由 `steam_api64.dll` / `libsteam_api.dylib` 提供 Steam ticket
2. **网络传输**：玩家位置、世界状态同步——Valheim 自己实现，走 UDP

Goldberg 替换的是第 1 部分：它提供假的 Steam 身份，让游戏以为自己是正版。而 `enable_lan_only=1` 关掉 Goldberg 的 Steam 网络模拟，让第 2 部分退回**纯 UDP 直连**。

关键点：**当传输层是 IP 直连时，服务端不会向 Steam 校验对方 ticket**。认证环节被整个跳过，所以两台 Goldberg 客户端能直接互通。

## 为什么不用专用服务器

官方 `valheim_server.exe` 启动时会做 Steam 初始化并校验。Goldberg 的假 ticket 在服务端侧容易被拒，表现为"服务端起来了，客户端连不上"。

**客户端自己开世界**时没有这个校验环节，只要两台客户端的 Goldberg 配置一致就能连。所以本方案采用"Windows 客户端开世界"而不是专用服务器。

代价：主机退出游戏，世界就关了。想让世界常驻见 `04-play-and-join.md` 的备选方案。

## 数据流

```
┌─────────────────────────────┐
│ Windows（主机 + 玩家）        │
│                             │
│  valheim.exe                │
│    ├─ steam_api64.dll       │ ← Goldberg（假身份）
│    │    └─ enable_lan_only  │ ← 关掉 Steam 网络
│    └─ 世界数据在内存         │
│         ↓ 监听 UDP 2456     │
└─────────────┬───────────────┘
              │ 局域网 UDP 2456
              │ （无 Steam 认证）
┌─────────────┴───────────────┐
│ Mac（客机）                  │
│                             │
│  Valheim.app                │
│    └─ libsteam_api.dylib    │ ← Goldberg（假身份）
│         └─ enable_lan_only  │
│         Join IP 192.168.x.x │
└─────────────────────────────┘
```

## 为什么两端必须版本一致

Valheim 的网络协议随版本变化。buildid 不同时，表现是"能握手但数据解析失败"，客户端卡在 `Connecting...` 然后超时，日志里可能只有一行模糊的错误。

所以 `docs/02` 第一步就是对齐 buildid。

## 为什么 account_steamid 必须不同

Goldberg 用 `account_steamid` 作为玩家唯一标识：

- 相同时：两个客户端被认为是同一个人，角色数据互相覆盖，可能出现"进去发现是对方的装备"
- 不同时：各自独立的角色存档

固定用两个不同的值，别用游戏自动生成的，避免重装后变化。

## 为什么 Windows 开世界、Mac 加入

技术上两边都能开，但 Windows 侧 Goldberg 成熟度更高（PE 加载、DLL 替换都是原生命令），出问题时排查路径短。Mac 侧涉及 dylib 架构和代码签名，作为客机更省心。

如果 Mac 是 Apple Silicon，注意 dylib 必须是 `arm64` 或 `universal`，纯 `x86_64` 会闪退。见 `03-mac-setup.md`。
