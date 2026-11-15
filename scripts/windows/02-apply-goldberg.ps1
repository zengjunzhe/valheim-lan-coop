# 02-apply-goldberg.ps1 — 给 Steam 版的 Valheim 打 Goldberg 补丁
# 用法:
#   powershell -ExecutionPolicy Bypass -File .\02-apply-goldberg.ps1 -GoldbergDir C:\goldberg
#   powershell -ExecutionPolicy Bypass -File .\02-apply-goldberg.ps1 -ValheimDir "D:\SteamLibrary\steamapps\common\Valheim" -GoldbergDir C:\goldberg -AccountName PlayerA -SteamId 76561198000000001
#
# 做的事:
#   1. 备份原版 steam_api64.dll → steam_api64.dll.orig
#   2. 覆盖为 Goldberg 的 steam_api64.dll
#   3. 创建 steam_settings 三个配置文件

[CmdletBinding()]
param(
    [string]$ValheimDir  = "",
    [string]$GoldbergDir = "C:\goldberg",
    [string]$AccountName = "PlayerA",
    [string]$SteamId     = "76561198000000001",
    [switch]$NoBackupCheck
)

$ErrorActionPreference = "Stop"
function Line { Write-Host ("-" * 62) -ForegroundColor DarkGray }
function Head { param($t) Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function OK   { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green }
function Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Bad  { param($t) Write-Host "  [FAIL] $t" -ForegroundColor Red }
function Info { param($t) Write-Host "         $t" -ForegroundColor Gray }

Write-Host ""
Write-Host "Valheim LAN Coop - 应用 Goldberg 补丁" -ForegroundColor White
Line

# ---------- 1. 定位 Valheim ----------
Head "定位 Valheim"
if (-not $ValheimDir) {
    $steamExe = $null
    foreach ($p in @("${env:ProgramFiles(x86)}\Steam\steam.exe", "$env:ProgramFiles\Steam\steam.exe", "D:\Steam\steam.exe")) {
        if (Test-Path $p) { $steamExe = $p; break }
    }
    if (-not $steamExe) {
        $reg = Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
        if ($reg -and $reg.SteamExe) { $steamExe = $reg.SteamExe }
    }
    if ($steamExe) {
        $steamRoot = Split-Path $steamExe -Parent
        $libs = @()
        $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            $m = Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches
            foreach ($mm in $m.Matches) { $libs += ($mm.Groups[1].Value -replace '\\\\','\') }
        }
        $libs += Join-Path $steamRoot "steamapps"
        foreach ($lib in $libs) {
            $c = Join-Path $lib "common\Valheim"
            if (Test-Path (Join-Path $c "valheim.exe")) { $ValheimDir = $c; break }
        }
    }
}
if (-not $ValheimDir -or -not (Test-Path (Join-Path $ValheimDir "valheim.exe"))) {
    Bad "未找到 Valheim。请用 -ValheimDir 手动指定"
    Info "示例: -ValheimDir `"D:\SteamLibrary\steamapps\common\Valheim`""
    exit 1
}
OK "Valheim: $ValheimDir"

# ---------- 2. Steam 进程检查 ----------
Head "检查 Steam 进程"
$sp = Get-Process steam -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sp) {
    Warn "Steam 正在运行。请完全退出（含托盘图标）后重新运行本脚本"
    Warn "命令: Stop-Process -Name steam -Force"
    $ans = Read-Host "  继续? (y/N)"
    if ($ans -ne "y") { exit 1 }
} else {
    OK "Steam 未运行"
}

# ---------- 3. 定位 Goldberg dll ----------
Head "定位 Goldberg dll"
$srcDll = $null
foreach ($p in @(
    (Join-Path $GoldbergDir "steam_api64.dll"),
    (Join-Path $GoldbergDir "x64\steam_api64.dll"),
    (Join-Path $GoldbergDir "release\steam_api64.dll"),
    (Join-Path $GoldbergDir "build\steam_api64.dll")
)) { if (Test-Path $p) { $srcDll = $p; break } }

if (-not $srcDll) {
    Bad "在 $GoldbergDir 找不到 steam_api64.dll"
    Info "请下载: https://github.com/Mr_Goldberg/goldberg_emulator/releases"
    Info "解压后确认里面有 x64/steam_api64.dll"
    exit 1
}
OK "源文件: $srcDll  ($((Get-Item $srcDll).Length) bytes)"

# 验证是 PE 文件（读前两字节，应为 'MZ'）
$fs = [System.IO.File]::OpenRead($srcDll)
try {
    $hdr = [byte[]]::new(2)
    [void]$fs.Read($hdr, 0, 2)
} finally { $fs.Close() }
if ($hdr[0] -ne 0x4D -or $hdr[1] -ne 0x5A) {
    Bad "$srcDll 不是有效的 Windows PE 文件（缺少 MZ 头）"
    Info "常见原因：下成了 Linux/macOS 构建，或文件下载不完整"
    exit 1
}
OK "PE 头校验通过"

# ---------- 4. 备份并覆盖 ----------
Head "备份并覆盖 dll"
$dllDir = Join-Path $ValheimDir "valheim_Data\Plugins\x86_64"
if (-not (Test-Path $dllDir)) {
    Bad "目录不存在: $dllDir"
    Info "Valheim 目录结构异常，请验证 Steam 安装完整性"
    exit 1
}
$dstDll = Join-Path $dllDir "steam_api64.dll"
$bakDll = "$dstDll.orig"

if (-not (Test-Path $dstDll)) {
    Bad "目标 dll 不存在: $dstDll"
    exit 1
}

if (-not (Test-Path $bakDll)) {
    Copy-Item $dstDll $bakDll -Force
    OK "已备份 → steam_api64.dll.orig ($((Get-Item $bakDll).Length) bytes)"
} else {
    Info "备份已存在，保留原始 .orig 不覆盖"
}

# 若当前 dll 已是 Goldberg（大小与源相同），跳过复制
$curSz = (Get-Item $dstDll).Length
$srcSz = (Get-Item $srcDll).Length
if ($curSz -eq $srcSz) {
    Info "当前 dll 大小与 Goldberg 源一致，可能已打过补丁（仍会重写）"
}

try {
    Copy-Item $srcDll $dstDll -Force
    OK "已覆盖 → $dstDll ($((Get-Item $dstDll).Length) bytes)"
} catch {
    Bad "覆盖失败: $($_.Exception.Message)"
    Info "可能被占用。请确认 valheim.exe 未运行"
    exit 1
}

# ---------- 5. steam_settings ----------
Head "创建 steam_settings"
$ss = Join-Path $ValheimDir "steam_settings"
New-Item -ItemType Directory -Force -Path $ss | Out-Null
OK "目录: $ss"

# steam_appid.txt
$appidFile = Join-Path $ss "steam_appid.txt"
Set-Content -Path $appidFile -Value "892970" -NoNewline -Encoding ASCII
OK "steam_appid.txt → 892970"

# configs.user.ini
$userIni = Join-Path $ss "configs.user.ini"
$userContent = @"
[user::general]
account_name=$AccountName
account_steamid=$SteamId
language=schinese
"@
Set-Content -Path $userIni -Value $userContent -Encoding ASCII
OK "configs.user.ini → $AccountName / $SteamId"

# configs.main.ini
$mainIni = Join-Path $ss "configs.main.ini"
$mainContent = @"
[main::general]
enable_lan_only=1

[main::connectivity]
disable_networking=0
"@
Set-Content -Path $mainIni -Value $mainContent -Encoding ASCII
OK "configs.main.ini → enable_lan_only=1（关键）"

# ---------- 6. 验证 ----------
Head "验证结果"
$checks = @(
    @{ Path = $dstDll;    Name = "steam_api64.dll (Goldberg)" },
    @{ Path = $bakDll;    Name = "steam_api64.dll.orig (原版备份)" },
    @{ Path = $appidFile; Name = "steam_appid.txt" },
    @{ Path = $userIni;   Name = "configs.user.ini" },
    @{ Path = $mainIni;   Name = "configs.main.ini" }
)
$allOk = $true
foreach ($c in $checks) {
    if (Test-Path $c.Path) {
        OK "$($c.Name)  ($((Get-Item $c.Path).Length) bytes)"
    } else {
        Bad "$($c.Name) 缺失"
        $allOk = $false
    }
}

Write-Host ""
Write-Host "  目录结构:" -ForegroundColor Gray
Write-Host "  $ValheimDir" -ForegroundColor DarkGray
Write-Host "  ├── valheim.exe" -ForegroundColor DarkGray
Write-Host "  ├── valheim_Data\Plugins\x86_64\" -ForegroundColor DarkGray
Write-Host "  │   ├── steam_api64.dll       ← Goldberg" -ForegroundColor DarkGray
Write-Host "  │   └── steam_api64.dll.orig  ← 原版" -ForegroundColor DarkGray
Write-Host "  └── steam_settings\" -ForegroundColor DarkGray
Write-Host "      ├── steam_appid.txt" -ForegroundColor DarkGray
Write-Host "      ├── configs.user.ini" -ForegroundColor DarkGray
Write-Host "      └── configs.main.ini" -ForegroundColor DarkGray

Line
if ($allOk) {
    OK "补丁应用成功"
    Write-Host ""
    Write-Host "下一步: 03-firewall.ps1（管理员）" -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\03-firewall.ps1" -ForegroundColor Gray
} else {
    Bad "有文件缺失，请检查上面的错误"
    exit 1
}
Write-Host ""
