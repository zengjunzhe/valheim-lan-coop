# 回滚到正版

任何时候都能回到干净状态。备份文件在替换时就已经生成，回滚不需要重新下载。

---

## Windows

```powershell
cd scripts\windows
powershell -ExecutionPolicy Bypass -File .\99-rollback.ps1
```

脚本做：

1. 关闭 `valheim.exe`
2. 从 `steam_api64.dll.orig` 恢复原版 dll
3. 移走 `steam_settings\` → `steam_settings.bak_时间戳`（不删除，可恢复）
4. 验证 dll 哈希与原版一致

可选参数：

```powershell
# 同时移除防火墙规则（需要管理员）
powershell -ExecutionPolicy Bypass -File .\99-rollback.ps1 -RemoveFirewall

# 保留 steam_settings（只恢复 dll）
powershell -ExecutionPolicy Bypass -File .\99-rollback.ps1 -KeepSettings

# 手动指定路径
powershell -ExecutionPolicy Bypass -File .\99-rollback.ps1 -ValheimDir "D:\SteamLibrary\steamapps\common\Valheim"
```

### 手动回滚

```powershell
$v = "D:\SteamLibrary\steamapps\common\Valheim"
Copy-Item "$v\valheim_Data\Plugins\x86_64\steam_api64.dll.orig" "$v\valheim_Data\Plugins\x86_64\steam_api64.dll" -Force
Rename-Item "$v\steam_settings" "steam_settings.bak"
Remove-NetFirewallRule -DisplayName "Valheim LAN*"
```

---

## Mac

```bash
cd scripts/mac
./99-rollback.sh
```

脚本做：

1. 关闭 Valheim 进程
2. 从 `libsteam_api.dylib.orig` 恢复
3. 移走所有 `steam_settings`（`find` 全 App 范围）
4. `xattr -cr` + 重新签名 + 清 quarantine
5. 验证 dylib 与原版一致、签名有效

可选参数：

```bash
./99-rollback.sh --keep-settings        # 只恢复 dylib
./99-rollback.sh --app /Applications/Valheim.app
```

### 手动回滚

```bash
DYLIB=$(find /Applications/Valheim.app -name "libsteam_api.dylib" -not -name "*.orig" | head -1)
cp "$DYLIB.orig" "$DYLIB"
find /Applications/Valheim.app -name "steam_settings" -maxdepth 6 -type d -exec mv {} {}.bak \;
xattr -cr /Applications/Valheim.app
codesign --force --deep --sign - /Applications/Valheim.app
xattr -dr com.apple.quarantine /Applications/Valheim.app
```

---

## 验证回滚成功

### Windows

```powershell
$v = "D:\SteamLibrary\steamapps\common\Valheim"
# 应该 False
Test-Path "$v\steam_settings"
# 两个哈希应该相同
(Get-FileHash "$v\valheim_Data\Plugins\x86_64\steam_api64.dll").Hash
(Get-FileHash "$v\valheim_Data\Plugins\x86_64\steam_api64.dll.orig").Hash
```

### Mac

```bash
# 应该 valid on disk / satisfies its Designated Requirement
codesign -vv /Applications/Valheim.app

# 通过 Steam 启动，应能正常进游戏
open steam://rungameid/892970
```

---

## 如果 .orig 备份丢了

Steam 验证文件完整性可以重新拿到原版 dll：

1. Steam → 库 → 右键 Valheim → 属性
2. 已安装文件 → 验证文件完整性
3. 等待校验完成，Steam 会自动下载缺失/被修改的文件

验证后 `steam_api64.dll` 恢复原版，但 `steam_settings` 目录不会被删（Steam 不认识它），需要手动删。

Mac 同理，验证后 `libsteam_api.dylib` 恢复，但需要重新签名（Steam 验证会重置签名）。

---

## 存档保留

回滚**不影响存档**：

- Windows：`%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\`
- Mac：`~/.config/unity3d/IronGate/Valheim\`

回滚后用正版启动，角色和世界都在。注意：

- 正版单机启动时，主机侧世界存档就是你的
- Mac 侧 `characters\` 里的角色依然可用

---

## 什么时候需要回滚

| 场景 | 是否需要 |
|---|---|
| 想买第二份游戏，改走官方联机 | 两台都回滚 |
| Mac 要恢复正版身份 | Mac 侧回滚（但就没法联机了） |
| 游戏更新后想临时玩单机 | 不必，Goldberg 版也能单机 |
| 排查问题 | 可先回滚验证是不是补丁引起 |
| 想彻底放弃本方案 | 两台都回滚，删防火墙规则 |
