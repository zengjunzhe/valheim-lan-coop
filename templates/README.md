# templates

这些是**参考副本**，脚本不读它们——`02-apply-goldberg.ps1` / `02-apply-goldberg.sh` 会直接把同样内容写进游戏的 `steam_settings/`。

留在这里是为了：

- 手动修复时可以直接拷
- 核对脚本写进去的内容是否正确
- 改身份时知道该改哪几行

| 文件 | 用途 |
|---|---|
| `steam_appid.txt` | 内容 `892970` |
| `configs.user.A.ini` | Windows 主机身份（`PlayerA` / `...0001`） |
| `configs.user.B.ini` | Mac 客机身份（`PlayerB` / `...0002`） |
| `configs.main.lan.ini` | `enable_lan_only=1`，联机核心配置 |
