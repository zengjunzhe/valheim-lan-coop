# sync/ — 两台机之间的中转目录

这个目录是 **Windows ↔ Mac 的数据管道**。详细说明见 [`docs/07-git-as-bridge.md`](../docs/07-git-as-bridge.md)。

## 目录归属

| 目录 | 谁写 | 谁读 |
|---|---|---|
| `shared/status-windows.md` | 只有 Windows | Mac |
| `shared/status-mac.md` | 只有 Mac | Windows |
| `shared/notes.md` | 双方追加 | 双方 |
| `saves/windows/` | 只有 Windows | Mac |
| `saves/mac/` | 只有 Mac | Windows |
| `diag/windows/` | 只有 Windows | Mac |
| `diag/mac/` | 只有 Mac | Windows |
| `from-windows/` | 只有 Windows | Mac |
| `from-mac/` | 只有 Mac | Windows |

**规则**：只写自己那半边，不动对方的目录。这样永远不会产生 Git 冲突。

## 日常命令

```powershell
# Windows
.\scripts\windows\07-sync-both.ps1                    # 双向同步
.\scripts\windows\06-sync-push.ps1 -IncludeSaves -Diag # 带存档和诊断
```

```bash
# Mac
./scripts/mac/07-sync-both.sh                         # 双向同步
./scripts/mac/06-sync-push.sh --saves --diag          # 带存档和诊断
```

## 不要放的东西

- 真 Steam 账号密码、API key、token
- 私钥、SSH key
- 任何超过 50MB 的单文件（脚本会跳过并提示）

仓库是 public 的，这些一旦推上去就撤不回来了。
