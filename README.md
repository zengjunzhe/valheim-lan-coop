# Valheim 局域网双人联机（一份 Steam 授权）

在两台电脑上实现《英灵神殿》局域网双人联机，**只买一份 Steam 游戏**。

- **两台都先用 Steam 下载**（同一账号各自下载，buildid 天然一致）
- **Mac**：打 Goldberg 补丁，客机
- **Windows**：打 Goldberg 补丁，主机（开世界）
- **联机**：局域网 UDP 直连，无 Steam 认证环节

> Windows 按 [`docs/00-checklist.md`](docs/00-checklist.md) + [`docs/02-windows-setup.md`](docs/02-windows-setup.md) 走，Mac 按清单 + [`docs/03-mac-setup.md`](docs/03-mac-setup.md) 走。

---

## 核心思路

```
① 两台都用 Steam 下载 Valheim（同账号，版本天然一致）
② 下载完退出 Steam，之后不再用它启动
③ 两台都替换 steam api 为 Goldberg（伪造身份）
④ steam_settings/configs.main.ini 里 enable_lan_only=1（关掉 Steam 网络，走 IP 直连）
⑤ Windows 开世界，Mac 用 Join IP 连
```

`enable_lan_only=1` 是整个方案成立的关键：没有它，Goldberg 的假 ticket 会在 Steam 认证握手时被拒。

---

## 为什么不用 Steam 直连

| 限制 | 说明 |
|---|---|
| 同账号并发 | 同一款游戏同时只能一个实例运行 |
| 家庭共享 | 同款游戏同时只能一人启动，共享者本人也受限 |
| 离线模式 | 需先在线验证，验证后并发限制依然生效 |

限制在**账户层**，不在游戏层，所以绕不过。Goldberg 替换的是身份认证环节，让第二台机器不需要真 Steam ticket。

---

## 目录结构

```
valheim-lan-coop/
├── README.md                      ← 你在这里
├── CHANGELOG.md
├── docs/
│   ├── 00-checklist.md            ← 照做版清单（先看这个）
│   ├── 01-architecture.md         ← 原理、为什么这么做
│   ├── 02-windows-setup.md        ← Windows 主机完整步骤
│   ├── 03-mac-setup.md            ← Mac 客机完整步骤
│   ├── 04-play-and-join.md        ← 开玩、加入、存档
│   ├── 05-troubleshooting.md      ← 排错表
│   └── 06-rollback.md             ← 回滚到正版
├── scripts/
│   ├── windows/
│   │   ├── 01-detect.ps1          ← 环境探测（先跑）
│   │   ├── 02-apply-goldberg.ps1  ← 打补丁
│   │   ├── 03-firewall.ps1        ← 防火墙放行
│   │   ├── 04-launch.ps1          ← 启动游戏
│   │   └── 99-rollback.ps1        ← 一键回滚
│   └── mac/
│       ├── 01-detect.sh
│       ├── 02-apply-goldberg.sh
│       ├── 03-resign.sh
│       ├── 04-launch.sh
│       └── 99-rollback.sh
└── templates/                     ← 参考副本，脚本不读
    ├── configs.user.A.ini         ← Windows 主机身份
    ├── configs.user.B.ini         ← Mac 客机身份
    ├── configs.main.lan.ini       ← enable_lan_only=1
    └── steam_appid.txt
```

---

## 快速开始

### 第一步：两台都用 Steam 下载

Windows 和 Mac 各自登录同一账号，在 Steam 里安装 Valheim。下载完**退出 Steam**。

### 第二步：Windows（主机）

```powershell
cd scripts\windows
powershell -ExecutionPolicy Bypass -File .\01-detect.ps1
```

记下输出里的两个值：`buildid` 和 `>>> Mac 侧 Join IP 填: 192.168.x.x:2456`

下载 Goldberg 到 `C:\goldberg`，然后：

```powershell
powershell -ExecutionPolicy Bypass -File .\02-apply-goldberg.ps1 -GoldbergDir C:\goldberg
powershell -ExecutionPolicy Bypass -File .\03-firewall.ps1
powershell -ExecutionPolicy Bypass -File .\04-launch.ps1
```

### 第三步：Mac（客机）

```bash
cd scripts/mac
chmod +x *.sh
./01-detect.sh
```

确认架构匹配（Apple Silicon 需 arm64/universal）。下载 Goldberg 到 `~/goldberg`，然后：

```bash
./02-apply-goldberg.sh --goldberg-dir ~/goldberg
./04-launch.sh --host 192.168.1.23
```

### 第四步：开玩

Windows 进游戏 → `Start Game` → 进世界
Mac → `Join Game` → `Join IP` → `192.168.1.23:2456`

---

## 三个配置文件（缺一不可）

| 文件 | 内容 | 作用 |
|---|---|---|
| `steam_settings/steam_appid.txt` | `892970` | 告诉 Goldberg 这是哪个游戏 |
| `steam_settings/configs.user.ini` | 两端 `account_steamid` 必须不同 | 玩家唯一标识 |
| `steam_settings/configs.main.ini` | `enable_lan_only=1` | 跳过 Steam ticket 校验 |

默认身份：

| 机器 | account_name | account_steamid |
|---|---|---|
| Windows | `PlayerA` | `76561198000000001` |
| Mac | `PlayerB` | `76561198000000002` |

---

## 前置条件

- 两台在**同一网段**（都是 `192.168.x.*`，第三段相同）
- 路由器**关闭 AP 隔离 / 客户端隔离**
- 两台 **buildid 相同**（Steam 下载天然一致）
- 局域网 UDP 2456-2458 互通
- Windows 网络位置设为**专用**，不是公用

---

## 已知代价

| 项 | 状态 |
|---|---|
| Steam 成就 | 不可用 |
| 云存档 | 不可用（手动拷） |
| 好友列表 / 邀请 | 不可用（用 IP 直连） |
| 主机退出游戏 | 全队断线（想让世界常驻见 `docs/04`） |
| 反作弊 | Valheim 无 VAC，无影响 |
| 存档位置 | 主机侧 `%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\` |

---

## 一键回滚

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\99-rollback.ps1
```

```bash
# Mac
./99-rollback.sh
```

恢复原版文件后可正常通过 Steam 启动，存档不受影响。

---

## 版本记录

见 [`CHANGELOG.md`](CHANGELOG.md)。
