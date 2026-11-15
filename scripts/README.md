# ⚠️ 这些脚本不能直接用

**本目录下的脚本基于错误的配置键（`enable_lan_only`），按现状执行必然失败。**

详见 [`../docs/08-verification.md`](../docs/08-verification.md)。

---

## 具体问题

| 脚本 | 问题 |
|---|---|
| `windows/02-apply-goldberg.ps1` | 写入 `configs.main.ini` 的 `enable_lan_only=1` — **该键不存在** |
| `mac/02-apply-goldberg.sh` | 同上，且 Mac 侧应写 `.txt` 而非 `.ini` |
| `windows/04-launch.ps1` | 默认端口 2456，但 emu 发现端口是 47584 |
| `mac/04-launch.sh` | 同上 |
| `*/01-detect.*` | 检查 `enable_lan_only`，该检查永远失败 |
| `*/05-sync-pull.*` | 逻辑可用，但展示的状态基于错误配置 |
| `*/06-sync-push.*` | 逻辑可用，同上 |
| `*/07-sync-both.*` | 逻辑可用 |

## 仍然可用的部分

- **`*/05-sync-pull.*` / `06-sync-push.*` / `07-sync-both.*`** — GitHub 中转逻辑本身没问题
- **`*/99-rollback.*`** — 回滚逻辑正确
- **`*/03-firewall.ps1`** — 放行 UDP 2456-2458 和 47584，需要补 47584
- **`*/03-resign.sh`** — 重签名流程正确

## 重写前必须先做的事

```
1. Mac 上实测 aaf2tbz dylib 能否加载
2. Windows 上实测 gbe_fork dll 能否加载
3. 确认 custom_broadcasts.txt 能否让 Valheim 互相发现
```

在这三步验证通过之前，重写脚本只是把错误换个形式。

## 正确的配置（供重写时参考）

### Windows（gbe_fork）

```
steam_settings/
├── steam_appid.txt          → 892970
├── configs.user.ini         → [user::general] account_name / account_steamid / language
├── configs.main.ini         → [main::connectivity] disable_networking=0 / listen_port=47584
└── custom_broadcasts.txt    → 广播地址 + 对端 IP
```

### macOS（aaf2tbz）

```
steam_settings/
├── steam_appid.txt          → 892970
├── account_name.txt         → PlayerB
├── user_steam_id.txt        → 76561198000000002
├── language.txt             → schinese
├── listen_port.txt          → 47584
└── custom_broadcasts.txt    → 广播地址 + 对端 IP
```
