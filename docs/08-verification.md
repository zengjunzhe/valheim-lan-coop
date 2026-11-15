# 事实核查（2026-11-15）

> **这份文档推翻了本仓库 v1.0 / v1.1 中的若干核心技术论断。**
> 之前的方案是凭印象写的，没有对照上游项目源码和二进制。这里记录实际查证结果。
>
> 结论：**`scripts/` 目录下的脚本基于错误配置键，按现状执行必然失败。**

---

## 一、错误清单

| # | 之前写的 | 实际情况 | 严重性 |
|---|---|---|---|
| 1 | Goldberg 下载地址 `github.com/Mr_Goldberg/goldberg_emulator` | **404，该仓库不存在**。原版在 `gitlab.com/Mr_Goldberg/goldberg_emulator` | 致命 |
| 2 | 核心配置 `enable_lan_only=1` | **该配置键不存在**，两个项目的二进制里都搜不到 | 致命 |
| 3 | 两端都写 `configs.main.ini` / `configs.user.ini` | Windows 的 gbe_fork 用 ini；**macOS 构建只认一堆 `.txt`**，两套格式不兼容 | 致命 |
| 4 | `steam_settings/steam_appid.txt` | Windows 侧正确；Mac 侧同样是 `steam_appid.txt`（这个对了） | 正确 |
| 5 | Mac 可能需要 CrossOver | **Valheim 有原生 macOS 版**，不需要 CrossOver | 冗余 |

---

## 二、实测证据

### 2.1 下载地址验证

```
$ curl -o /dev/null -w "%{http_code}" https://github.com/Mr_Goldberg
404

$ curl -o /dev/null -w "%{http_code}" https://github.com/Mr_Goldberg/goldberg_emulator
404
```

原版实际位置（GitLab API）：

```
name: goldberg_emulator
star_count: 1094
forks_count: 426
last_activity_at: 2026-09-21
web_url: https://gitlab.com/Mr_Goldberg/goldberg_emulator
description: Steam emulator that emulates steam online features. Lets you play games
             that use the steam multiplayer apis on a LAN without steam or an internet
             connection.
```

### 2.2 配置键不存在

下载两个项目的实际二进制，用 `strings` 统计键名出现次数：

```bash
# Detanup01/gbe_fork release-2026_09_27 (Windows)
# aaf2tbz/goldberg_emulator latest (macOS dylib)
```

| 配置键 | gbe_fork dll | aaf2tbz dylib | 说明 |
|---|---|---|---|
| `enable_lan_only` | **0** | **0** | **不存在** |
| `disable_lan_only` | 2 | 2 | 存在，但含义相反：1 = 关闭 LAN-only 限制、允许外网 |
| `disable_networking` | 有 | 有 | 存在 |
| `listen_port` | 有 | 有 | 存在 |
| `custom_broadcasts` | 有 | 有 | 存在 |
| `old_p2p_packet_sharing_mode` | 仅 gbe_fork | **0** | macOS 构建无此项 |

**`enable_lan_only` 是我编的。** 真正存在的 `disable_lan_only` 语义是：

> `1=prevent hooking OS networking APIs and allow any external requests`
> 即「关闭 LAN 限制」，跟"只走局域网"**意思相反**。

gbe_fork 官方 `post_build/README.experimental.md` 原文：

```
## To disable the LAN only connections feature
Modify your steam_settings\configs.main.ini and set disable_lan_only=1.
```

### 2.3 配置格式分叉

**gbe_fork（Windows）** 用 ini，实测 `post_build/steam_settings.EXAMPLE/` 内容：

```
configs.main.EXAMPLE.ini
configs.user.EXAMPLE.ini
configs.app.EXAMPLE.ini
configs.overlay.EXAMPLE.ini
custom_broadcasts.EXAMPLE.txt
steam_appid.EXAMPLE.txt
steam_interfaces.EXAMPLE.txt
...
```

**aaf2tbz（macOS）** 只认 txt，实测 `files_example/steam_settings.EXAMPLE/`：

```
account_name.txt
user_steam_id.txt
listen_port.txt
custom_broadcasts.txt
disable_networking.txt
force_steamid.txt
force_account_name.txt
force_listen_port.txt
local_save.txt
steam_appid.txt
steam_interfaces.txt
offline.txt
...
```

从 dylib 里直接提取的配置文件名列表（`strings` 结果）：

```
account_name.txt        app_paths.txt         build_id.txt
custom_broadcasts.txt   depots.txt            disable_lobby_creation.txt
disable_networking.txt  disable_overlay.txt   force_account_name.txt
force_language.txt      force_listen_port.txt force_steamid.txt
language.txt            leaderboards.txt      listen_port.txt
local_save.txt          offline.txt           revision.txt
stats.txt               steam_appid.txt       steam_interfaces.txt
subscribed_groups.txt   supported_languages.txt user_steam_id.txt
```

**没有任何 `.ini` 文件被引用。**

### 2.4 macOS 构建的真实性

`aaf2tbz/goldberg_emulator` release `latest`（2026-08-14）资产：

| 文件 | 大小 |
|---|---|
| `libsteam_api.dylib` | 5903 KB |
| `libsteam_api64.dll` | 5908 KB |
| `libsteamclient64.dll` | 101 KB |
| `libsteamnetworkingsockets64.dll` | 116 KB |
| `generate_interfaces_file` | 225 KB |
| `lobby_connect` | 5569 KB |

实测 `libsteam_api.dylib`：

```
$ file libsteam_api.dylib
Mach-O universal binary with 2 architectures:
  [x86_64: Mach-O 64-bit x86_64 dynamically linked shared library]
  [arm64:  Mach-O 64-bit arm64 dynamically linked shared library]

$ 魔数
cafebabe  → FAT universal (BE)
```

**Universal binary，x86_64 + arm64 都有，Apple Silicon 可用。**

导出符号（`strings` 统计）：372 个 `Steam*` 符号，含
`SteamNetworkingSockets001/002/003/004/006/008/009/011/012/013`、
`SteamMatchmaking`、`SteamAPI_Init`。

Windows dll 校验：

```
MZ: b'MZ'
PE offset: 0x80   sig: b'PE\x00\x00'
machine: 0x8664 (x64)   ← 正确，不是 x86
```

### 2.5 存档路径（Mac）

从 dylib 二进制里提取的实际拼接逻辑：

```c
// 非 Windows 分支
char *datadir = getenv("XDG_DATA_HOME");
if (datadir) {
    user_appdata_path = datadir;
} else {
    char *homedir = getenv("HOME");
    if (homedir) user_appdata_path = std::string(homedir) + "/.local/share";
}
return user_appdata_path + "/" + PROGRAM_NAME_1..8 + " Saves";
```

二进制里 `PROGRAM_NAME_1..8` 的实际字节（用 Python 直接读文件定位 ` Saves` 前的内容）：

```
Go\0ld\0be\0rg \0St\0ea\0mE\0mu\0 Saves\0
```

拼接结果：**`~/Library/Application Support/Goldberg SteamEmu Saves/`**

> ⚠️ 注意：**不是** `~/.config/unity3d/IronGate/Valheim`。
> 那个是 Valheim 自己的存档目录，Goldberg 的 `steam_settings` 和它无关。
> 之前文档里把两者混为一谈是错的。

`steam_settings` 目录的查找位置（二进制字符串上下文）：

```
... SteamNetworkingSockets013 \0 %u.%u.%u.%i \0 steam_settings \0 XDG_DATA_HOME \0 ...
```

即 `steam_settings` 相对 emu 库所在目录（`local_save.txt` 可覆盖）。

### 2.6 Valheim 平台支持

Steam Store API 实测：

```json
{
  "platforms": { "windows": true, "mac": true, "linux": true },
  "release_date": { "coming_soon": false, "date": "Sep 9, 2026" }
}
```

**有原生 macOS 版，不需要 CrossOver / Parallels。**

---

## 三、上游项目的已知问题

### 3.1 gbe_fork 破坏过 Valheim 联机（已修复）

**Issue #396** — `Multiplayer dosnt work with the new version`（2025-12-17 提出，2026-01-18 关闭）

报告者日志（Valheim 专用服务器）：

```
[valheim_server.log]: Game server connected
[valheim_server.log]: Got status changed msg k_ESteamNetworkingConnectionState_Connecting
[valheim_server.log]: New connection
[valheim_server.log]: Accepting connection k_EResultOK
[valheim_server.log]: Got connection SteamID {EMU_ID}
[valheim_server.log]: Failed to send data k_EResultFail   ← 卡在这
```

报告者总结：

> after Release 2025 09 13 and above multiplayer broke for a lot of games:
> satisfactory, risk of rain 2, **valheim**, liars bar and more

**修复确认**（2026-01-17）：

```
[elyashivhazan] @Detanup01 its working with the new build
```

**结论：必须用 2026-01-17 之后的 gbe_fork 构建。** 更早的版本会失败。

维护者 `otavepto` 排查时的关键提示：

> Did you make sure to remove `disable_networking=1`, or better override it with
> `disable_networking=0` in the local steam_settings folder.

**`disable_networking` 必须为 0**（默认就是 0，但别误设成 1）。

### 3.2 Valheim 联机协议

**Issue #41** — `Add support for steam's lan game servers`（2024-09-15，已关闭）

报告者描述：

> valheim the server supports 2 protocols: **playfab** (as of this date) after the last
> update playfab is not accessable with goldberg emu and must be used with steam
> (kind of a drm only for mp) but the server also supports **lan but with steam server
> browser**. with that feature lan will be passable in valheim with dedicated server.
> **do note that lan is still playable with hosting the world file one of the players
> host (but that host must play for someone else to play)**

关键信息：

1. Valheim 有**两套联机协议**：PlayFab 和 LAN（走 Steam server browser）
2. **PlayFab 无法用 Goldberg 模拟**（需要真 Steam ticket）
3. LAN 协议**可以**，但依赖 Steam 服务器浏览器发现机制
4. 玩家自己开世界（非专用服务器）是可行的 LAN 路径

维护者 `Detanup01` 的答复：

> Already existing called `custom_broadcasts.txt`
> you can add your/friends/vpn ip and broadcast address (ends with .255) to able to
> others to see it. and `lobby_connect` also exist for this reason to see who and
> what users playing in the broadcasted network

**所以正确的局域网发现机制是 `custom_broadcasts.txt`**，不是任何 `enable_lan_only`。

`custom_broadcasts.txt` 格式（官方示例）：

```
192.168.3.255
127.8.9.10
192.168.66.99
192.168.7.99
removethis.test.domain.com
```

即：广播地址（`.255`）+ 对端 IP，一行一个。

### 3.3 macOS 官方不支持

**Issue #189** — `[Feature] Mac Support`（2025-03-14，**仍 open**）

维护者 `Detanup01`：

> I do not have a macOS so couldnt test nor do anything with mac.
> And also like 2% of people playing/releasing on mac

社区推荐的替代（2026-08-16）：

> use this one: https://github.com/aaf2tbz/goldberg_emulator

**Mac 侧没有官方支持，只能依赖第三方 fork。**

---

## 四、可用的 macOS 构建选项

搜索结果（按 star / 活跃度）：

| 仓库 | ★ | 最后推送 | 说明 |
|---|---|---|---|
| `aaf2tbz/goldberg_emulator` | 6 | 2026-08-14 | **实测可用**，universal binary，SDK v1.0–v1.65 全接口 |
| `squareloopthings/goldberg-mac` | 1 | 2026-08-23 | Apple Silicon 专用 |
| `bitmap4/goldberg-mac-shim` | 1 | 2026-06-22 | 兼容层，让旧 Goldberg 跑在 Mac |
| `da-wood69/goldberg-emulator-macos` | 0 | 2026-09-02 | universal 构建脚本 |
| `surf5726/goldberg_emulator_macos` | 0 | 2026-06-25 | 个人修改版 |
| `s690759602/goldberg_emulator` | 2 | 2023-03-28 | 老版本，仅 x86_64 |

**首选 `aaf2tbz/goldberg_emulator`**：唯一实测确认 universal binary + 完整 SDK 覆盖 + 有 CI 构建。

风险：6 star、单作者、2026-08-14 一天内推完所有 commit。不是可靠长期依赖。

---

## 五、修正后的正确配置

### Windows（gbe_fork，release-2026_01_17 之后）

```
<Valheim>/steam_settings/
├── steam_appid.txt          → 892970
├── configs.user.ini         → account_name / account_steamid / language
├── configs.main.ini         → [main::connectivity] disable_networking=0
│                              listen_port=47584（两端一致）
└── custom_broadcasts.txt    → 广播地址 + 对端 IP
```

`configs.user.ini`：

```ini
[user::general]
account_name=PlayerA
account_steamid=76561198000000001
language=schinese
```

`configs.main.ini`：

```ini
[main::connectivity]
disable_networking=0
listen_port=47584
```

`custom_broadcasts.txt`：

```
192.168.1.255
192.168.1.23
192.168.1.45
```

（第一行是本网段广播地址，后两行是两台机的实际 IP）

### macOS（aaf2tbz）

```
Valheim.app/Contents/.../steam_settings/
├── steam_appid.txt          → 892970
├── account_name.txt         → PlayerB
├── user_steam_id.txt        → 76561198000000002
├── language.txt             → schinese
├── disable_networking.txt   → 0（或直接不创建，默认 0）
├── listen_port.txt          → 47584
└── custom_broadcasts.txt    → 同上
```

**注意 `listen_port` 默认 47584，不是 2456。** 2456 是 Valheim 自己的游戏端口，两者不同：
- `47584` — Goldberg emu 的发现端口（两端必须一致）
- `2456` — Valheim 游戏数据端口（`Join IP` 填这个）

之前文档把两者混为一谈是错的。

---

## 六、未验证的部分

诚实标注，以下**没有**实测：

| 项 | 状态 |
|---|---|
| Valheim + gbe_fork 双端实际联机成功 | 未验证。issue #396 说修复了，但那是专用服务器场景 |
| aaf2tbz dylib 在真实 Valheim.app 上加载 | 未验证。只验了二进制格式和符号 |
| Windows ini 与 Mac txt 配置混用能否互通 | 未验证。两者底层网络实现应该一致，但未实测 |
| `custom_broadcasts.txt` 能否让 Valheim 发现对端 | 未验证。issue #41 说可以，但没给出 Valheim 具体步骤 |
| macOS 代码签名流程 | 未验证。理论上需 `codesign --force --deep --sign -` |
| Valheim 原生 Mac 版是否真的用 `libsteam_api.dylib` | 未验证。需实际 `find Valheim.app -name "*steam_api*"` |

---

## 七、结论

1. **本仓库 `scripts/` 目录的脚本不能直接用**，配置键全错
2. **没有现成项目可抄**。GitHub 搜索 `valheim goldberg guide` / `valheim coop one copy` / `valheim multiplayer emulator` 全部 0 结果
3. 方案**技术上可能可行**，但依赖：gbe_fork ≥ 2026-01-17 + aaf2tbz macOS 构建 + `custom_broadcasts.txt` 配置
4. **必须先做单机验证**（Mac 上替换 dylib → 游戏能启动 → 能进单人世界），再谈双人联机

### 建议的下一步

```
阶段 1（Mac 单机验证）
  find Valheim.app -name "*steam_api*"     ← 确认路径和原文件
  替换 aaf2tbz dylib + 写 steam_settings
  codesign --force --deep --sign -
  启动 → 能进单人世界 = 通过

阶段 2（Windows 单机验证）
  同样流程，用 gbe_fork

阶段 3（联机验证）
  配 custom_broadcasts.txt
  两端同网段，试 LAN 发现 / Join IP

阶段 4（才写脚本自动化）
```

**在阶段 1 通过之前，任何脚本都是空转。**
