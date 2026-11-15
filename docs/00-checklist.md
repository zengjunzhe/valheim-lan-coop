# 操作清单（打印/照做版）

两台电脑各按自己的清单走。**顺序不能乱**。

---

## 两台共同的第一步：Steam 下载

| 步骤 | Windows | Mac |
|---|---|---|
| 1 | 打开 Steam，登录**你的账号** | 打开 Steam，登录**同一个账号** |
| 2 | 库 → Valheim → 安装 | 库 → Valheim → 安装 |
| 3 | 等下载完成，**不要启动游戏** | 等下载完成，**不要启动游戏** |
| 4 | 记下安装路径（右键 → 管理 → 浏览本地文件） | 无需记路径，脚本自动找 |
| 5 | **完全退出 Steam**（含托盘图标） | **完全退出 Steam**（Cmd+Q + 菜单栏图标） |

> 两台用同一账号下载，buildid 必然一致，省掉版本对齐。

---

## Windows 清单

```
□ 1. 以管理员身份打开 PowerShell
□ 2. cd 到 scripts\windows
□ 3. 跑 01-detect.ps1
      记下：buildid = __________
      记下：Mac 要填的 IP = __________:2456
□ 4. 下载 Goldberg → 解压到 C:\goldberg
      确认 C:\goldberg 里有 steam_api64.dll
□ 5. 跑 02-apply-goldberg.ps1 -GoldbergDir C:\goldberg
      确认输出「补丁应用成功」
□ 6. 跑 03-firewall.ps1（管理员）
      确认网络位置是「专用」，不是「公用」
□ 7. 跑 04-launch.ps1
      确认「Steam 未运行」「已启动」
□ 8. 游戏内 Start Game → 新建/选世界 → 真正进入世界
□ 9. 按 F5 看控制台，无报错
□ 10. 把 IP:2456 告诉 Mac
```

---

## Mac 清单

```
□ 1. 打开终端，cd 到 scripts/mac
□ 2. chmod +x *.sh
□ 3. 跑 01-detect.sh
      确认「架构匹配」（Apple Silicon 需 arm64/universal）
      记下：buildid = __________  ← 必须和 Windows 相同
□ 4. 下载 Goldberg → 解压到 ~/goldberg
      确认 ~/goldberg 里有 libsteam_api.dylib
      没有 → 该 release 无 macOS 构建，走 CrossOver 备选
□ 5. 跑 02-apply-goldberg.sh --goldberg-dir ~/goldberg
      确认「补丁应用成功」「重签名完成」
□ 6. 跑 04-launch.sh --host <Windows的IP>
      确认「进程运行中」
□ 7. 游戏内 Join Game → Join IP → 填 IP:2456
□ 8. 连上后确认角色出现
```

---

## 两端对照表

| 项 | Windows | Mac |
|---|---|---|
| 角色 | 主机 + 玩家 A | 客机 + 玩家 B |
| `account_name` | `PlayerA` | `PlayerB` |
| `account_steamid` | `76561198000000001` | `76561198000000002` |
| 启动参数 | `-console -port 2456` | 无 |
| 加入方式 | 自己开世界 | `Join IP` |
| 端口 | 监听 2456 | 不需要 |

**两个 `account_steamid` 必须不同**，相同会导致角色数据互相覆盖。

---

## 一句话验证是否配好

### Windows

```powershell
$v = "D:\SteamLibrary\steamapps\common\Valheim"   # 换成实际路径
Test-Path "$v\steam_settings\configs.main.ini"     # True
Select-String "$v\steam_settings\configs.main.ini" -Pattern "enable_lan_only=1"  # 有输出
Test-Path "$v\valheim_Data\Plugins\x86_64\steam_api64.dll.orig"  # True
```

### Mac

```bash
./01-detect.sh | grep -E "架构匹配|enable_lan_only|buildid"
```

三项都对 → 可以开玩。

---

## 出问题先看这三个

1. **`enable_lan_only=1` 两端都设了吗？** 缺一个就连不上
2. **buildid 两端一样吗？** 不一样就连不上
3. **Windows 网络位置是「专用」吗？** 是「公用」防火墙规则不生效

详细排错见 [`05-troubleshooting.md`](05-troubleshooting.md)。
