# Mac 单机验证：已通过（2026-11-15 实测）

> 本文取代 `01~05`、`09` 中关于 macOS 的推测部分。所有条目都是在本机实测得到的，不是查资料推出来的。
>
> 环境：macOS 27.2.1 (26B131)，Apple M1 Pro，Steam 版 Valheim build 26249040，Unity 6000.0.75f1。

---

## 结论

| 项 | 结果 |
|---|---|
| `aaf2tbz` 的 macOS dylib 能否注入 Valheim | ✅ 能 |
| 游戏能启动到主菜单 | ✅ |
| 能新建世界并进入、正常操作 | ✅ |
| 中文界面 | ✅（需改用户级 `language.txt`） |
| PlayFab 登录 | ❌ 必然失败（伪造 ticket 无效），不影响单人/LAN |

日志证据（`~/Library/Logs/IronGate/Valheim/Player.log`）：

```
Using steam_appid.txt
Using steam APPID:892970
Using environment steamid 892970
Authentication:k_ESteamNetworkingAvailability_Current
Steam initialized, persona:PlayerA
```

之后的 `Steam API AuthenticateUserTicket ... Invalid parameter` 是 PlayFab 在重试，属预期。

---

## 与旧文档不一致的地方（以本节为准）

| 项 | 旧文档 | 实测 |
|---|---|---|
| 下载地址 | `aaf2tbz/goldberg_emulator` release | 对，但 asset 名就是 `libsteam_api.dylib`，tag 是 `latest` |
| dylib 位置 | `Valheim.app/Contents/PlugIns/../libsteam_api.dylib` | 在 `valheim.app/Contents/PlugIns/steam_api.bundle/Contents/MacOS/libsteam_api.dylib`（**包名是小写 valheim.app，且在 .bundle 里面**） |
| `steam_settings` 位置 | `Valheim.app/Contents/MacOS/steam_settings` | **必须放在 dylib 同级**：`.../steam_api.bundle/Contents/MacOS/steam_settings/`。放 exe 目录、放 CWD 都无效 |
| 存档目录 | `~/Library/Application Support/Goldberg SteamEmu Saves/` | `~/.local/share/Goldberg SteamEmu Saves/` |
| 玩家名 | `account_name.txt`（游戏目录） | 用户级 `account_name.txt` **优先级更高**，会压过游戏目录；要强制用 `force_account_name.txt` |
| SteamID | `user_steam_id.txt` | **无效**，会被忽略并覆写成一个随机 ID；要固定必须用 `force_steamid.txt` |
| 配置格式 | macOS 只认 `.txt` | 对。字符串表里根本没有任何 `.ini` 键名 |
| `enable_lan_only` | 不存在 | 对，确认不存在 |
| 发现端口 | 47584 | 对，默认值就是 47584（首次运行自动生成 `listen_port.txt`） |
| `custom_broadcasts.txt` | LAN 发现靠它 | 键存在，但**效果尚未验证**（需要两台机器） |
| 符号兼容性 | 372 个导出 | 原库 1069 个导出，Goldberg 覆盖率 100%（arm64 与 x86_64 都是，缺 0 个） |
| 需不需要重签名 | "必需" | 需要重签名才能让签名自洽，但**重签名后 `codesign -v` 仍会报 `nested code is modified or invalid`，不影响启动** |

---

## 实际可行的步骤

### 1. 不要直接改 Steam 安装目录里的那一份

原因见下面「坑 1」。做法是 APFS 克隆一份到 `~/Games`（瞬间完成，不占额外空间）：

```bash
V="$HOME/Library/Application Support/Steam/steamapps/common/Valheim"
G="$HOME/Games/Valheim"
mkdir -p "$G"
cp -Rc "$V/valheim.app" "$G/valheim.app"
cp "$V/steam_appid.txt" "$G/steam_appid.txt"
```

### 2. 装 dylib

```bash
BUNDLE="$G/valheim.app/Contents/PlugIns/steam_api.bundle"
cp -f ~/goldberg/libsteam_api.dylib "$BUNDLE/Contents/MacOS/libsteam_api.dylib"
```

### 3. 写 steam_settings（放在 dylib 同级）

```bash
SS="$BUNDLE/Contents/MacOS/steam_settings"
mkdir -p "$SS"
printf '892970'   > "$SS/steam_appid.txt"
printf '47584'    > "$SS/listen_port.txt"
printf '0'        > "$SS/disable_networking.txt"
printf 'schinese' > "$SS/language.txt"
```

### 4. 重签名（先内层再外层）

```bash
codesign --force --sign - --preserve-metadata=entitlements,requirements,flags "$BUNDLE"
codesign --force --deep --sign - --preserve-metadata=entitlements,requirements,flags "$G/valheim.app"
```

`--preserve-metadata=entitlements,flags` 不能省：主程序的
`com.apple.security.cs.disable-library-validation`（允许加载非同签名的 dylib）和
`com.apple.security.cs.allow-dyld-environment-variables` 都靠它保留。

### 5. 身份写在用户级目录（每台机一份）

```bash
U="$HOME/.local/share/Goldberg SteamEmu Saves/settings"
mkdir -p "$U"
printf 'PlayerA'           > "$U/account_name.txt"
printf 'schinese'          > "$U/language.txt"
printf '47584'             > "$U/listen_port.txt"
# SteamID 首次运行会自动生成随机值，两端天然不同，一般不用管
```

### 6. 启动（不需要 Steam 在跑）

```bash
open -n "$G/valheim.app"
```

---

## 坑 1：本机的 Gatekeeper 评估链是坏的

`log show` 里持续出现：

```
syspolicyd: Error checking with notarization daemon: 3
syspolicyd: Unable to initialize qtn_proc: 3
syspolicyd: GatekeeperPolicyScanError Code=-67018 "Code did not match any currently allowed policy"
```

症状：**`~/Library/Application Support/Steam/.../valheim.app` 这个路径下启动会永远卡死在 dyld**
（进程常驻 32KB RSS、0 CPU，`sample` 显示只有 `_dyld_start` 一帧），而且是"卡住"不是"报错"。

关键是：把**字节完全一致**的副本放到别的路径（`~/Games/...`、甚至同目录下改个名字）就能正常启动。
所以这是**按路径失效的评估缓存**，不是 Valheim 或 Goldberg 的问题。

处理：

- 省事：用 `~/Games` 的副本玩，别碰 Steam 那份
- 修复：`sudo killall syspolicyd`，或重启系统
- 验证是否恢复：`spctl -a -vv <path>` 应显示 `accepted / Notarized Developer ID`

## 坑 2：Valheim 自己也会找 `steam_appid.txt`

实测日志既打印 `Using steam_appid.txt` 也打印 `Using environment steamid 892970`。
它从 exe 所在目录**逐层向上**找 `steam_appid.txt`，所以把 `steam_appid.txt` 放在
`~/Games/Valheim/steam_appid.txt`（`.app` 的同级）最稳。

## 坑 3：PlayFab 一定登录失败

`/Client/LoginWithSteam` 返回 `errorcode:3 Invalid parameter`，每 16 秒重试一次。
Goldberg 造不出真 ticket，官方跨平台联机（PlayFab）这条路对 Goldberg 是死的。
只能走 LAN（Steam server browser）。

## 坑 4：本机有 TUN 代理

`utun4` 上挂着 `198.18.0.1/30`（Clash/Surge 类 TUN 模式）。
做 LAN 联机时它很可能吃掉广播或改路由，届时先关掉再排查。

## 本机网络

| 项 | 值 |
|---|---|
| en0 | 192.168.5.11/24 |
| 广播地址 | 192.168.5.255 |
| 网关 | 192.168.5.1 |

---

## 下一步（未验证）

1. 第二台机（Windows）装 `gbe_fork`，重复阶段 2 → 见 `02-windows-setup.md`（注意其中的 `.ini` 是对的，Windows 构建读 ini）
2. 两端写 `custom_broadcasts.txt`：
   ```
   192.168.5.255
   192.168.5.11
   <Windows 的 IP>
   ```
3. 主机进世界 → 客机 `Join Game`，先看 LAN 标签页，再试 `Join IP: <主机IP>:2456`
