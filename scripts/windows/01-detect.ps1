# 01-detect.ps1 — Windows 环境探测（Steam 版）
# 用法: powershell -ExecutionPolicy Bypass -File .\01-detect.ps1
#
# 前提: 已经用 Steam 客户端把 Valheim 下载好（同一个 Steam 账号在两台机器分别下载）

[CmdletBinding()]
param(
    [string]$ValheimDir = ""
)

$ErrorActionPreference = "Continue"
function Line { Write-Host ("-" * 62) -ForegroundColor DarkGray }
function Head { param($t) Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function OK   { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green }
function Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Bad  { param($t) Write-Host "  [FAIL] $t" -ForegroundColor Red }
function Info { param($t) Write-Host "         $t" -ForegroundColor Gray }

Write-Host ""
Write-Host "Valheim LAN Coop - Windows 环境探测（Steam 版）" -ForegroundColor White
Line

# ---------- 系统 ----------
Head "系统"
$os = Get-CimInstance Win32_OperatingSystem
Info "OS        : $($os.Caption) $($os.Version)"
Info "架构      : $env:PROCESSOR_ARCHITECTURE"
Info "主机名    : $env:COMPUTERNAME"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) { OK "管理员权限: 是" } else { Warn "管理员权限: 否（改防火墙需要）" }

# ---------- 定位 Steam ----------
Head "Steam 与 Valheim"
$steamExe = $null
$candidates = @(
    "${env:ProgramFiles(x86)}\Steam\steam.exe",
    "$env:ProgramFiles\Steam\steam.exe",
    "D:\Steam\steam.exe",
    "E:\Steam\steam.exe"
)
foreach ($p in $candidates) { if (Test-Path $p) { $steamExe = $p; break } }

if (-not $steamExe) {
    $reg = Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
    if ($reg -and $reg.SteamExe) { $steamExe = $reg.SteamExe }
}

if ($steamExe) {
    OK "Steam: $steamExe"
    $steamRoot = Split-Path $steamExe -Parent
} else {
    Bad "未找到 Steam。请先安装 Steam 并登录下载 Valheim"
}

# ---------- 定位库文件夹 ----------
if (-not $ValheimDir) {
    $libPaths = @()
    if ($steamRoot) {
        $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            $m = Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches
            foreach ($mm in $m.Matches) {
                $libPaths += $mm.Groups[1].Value -replace '\\\\', '\'
            }
        }
        $libPaths += Join-Path $steamRoot "steamapps"
    }

    foreach ($lib in $libPaths) {
        $cand = Join-Path $lib "common\Valheim"
        if (Test-Path (Join-Path $cand "valheim.exe")) { $ValheimDir = $cand; break }
    }
}

if (-not $ValheimDir) {
    Bad "未找到 Valheim 安装目录"
    Info "请先在 Steam 里安装 Valheim，或手动指定: -ValheimDir `"D:\SteamLibrary\steamapps\common\Valheim`""
    Line
    exit 1
}

OK "Valheim: $ValheimDir"

# ---------- 游戏文件 ----------
Head "游戏文件"
$exe = Join-Path $ValheimDir "valheim.exe"
if (Test-Path $exe) {
    OK "valheim.exe  ($((Get-Item $exe).Length) bytes)"
} else {
    Bad "valheim.exe 不存在"
}

$dllDir  = Join-Path $ValheimDir "valheim_Data\Plugins\x86_64"
$dll     = Join-Path $dllDir "steam_api64.dll"
$dllOrig = "$dll.orig"
if (Test-Path $dll) {
    $sz = (Get-Item $dll).Length
    $h  = (Get-FileHash $dll -Algorithm SHA256).Hash.Substring(0,16)
    OK "steam_api64.dll  $sz bytes  sha256:$($h)..."
    Info "路径: $dll"
} else {
    Bad "steam_api64.dll 不存在"
    Info "预期路径: $dllDir"
}

if (Test-Path $dllOrig) {
    OK "已存在备份 steam_api64.dll.orig（补丁已应用过）"
} else {
    Info "无 .orig 备份（尚未打补丁，正常）"
}

$ss = Join-Path $ValheimDir "steam_settings"
if (Test-Path $ss) {
    OK "steam_settings 存在:"
    Get-ChildItem $ss -File | ForEach-Object { Info "  $($_.Name)  ($($_.Length) bytes)" }
    $userIni = Join-Path $ss "configs.user.ini"
    if (Test-Path $userIni) {
        $sid = Select-String -Path $userIni -Pattern "account_steamid\s*=\s*(\S+)"
        if ($sid) { Info "当前 account_steamid = $($sid.Matches[0].Groups[1].Value)" }
    }
    $mainIni = Join-Path $ss "configs.main.ini"
    if (Test-Path $mainIni) {
        $lan = Select-String -Path $mainIni -Pattern "enable_lan_only\s*=\s*(\d)"
        if ($lan) {
            if ($lan.Matches[0].Groups[1].Value -eq "1") { OK "enable_lan_only = 1（正确）" }
            else { Bad "enable_lan_only = 0（必须改成 1）" }
        }
    }
} else {
    Info "steam_settings 不存在（尚未打补丁）"
}

# ---------- buildid ----------
Head "版本（与 Mac 必须一致）"
$acf = Join-Path (Split-Path (Split-Path $ValheimDir -Parent) -Parent) "appmanifest_892970.acf"
if (Test-Path $acf) {
    $m = Select-String -Path $acf -Pattern '"buildid"\s+"(\d+)"'
    if ($m) {
        Write-Host ""
        Write-Host "  buildid = $($m.Matches[0].Groups[1].Value)" -ForegroundColor Magenta
        Write-Host ""
    }
} else {
    Info "未找到 appmanifest_892970.acf（路径: $acf）"
}
Info "Mac 侧核对: grep buildid ~/Library/Application\ Support/Steam/steamapps/appmanifest_892970.acf"

# ---------- Steam 进程 ----------
Head "Steam 进程状态"
$sp = @(Get-Process steam -ErrorAction SilentlyContinue)
if ($sp.Count -gt 0) {
    Warn "Steam 正在运行（$($sp.Count) 个进程）"
    Warn "打补丁和启动游戏前请完全退出 Steam，包括托盘图标"
    Warn "原因：Steam 在线会校验授权，也会顶掉 Mac 侧同账号登录"
} else {
    OK "Steam 未运行（正确状态）"
}

# ---------- 网络 ----------
Head "网络（Mac 要填这个 IP）"
$ips = Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }
if ($ips) {
    foreach ($ip in $ips) {
        $iface = Get-NetAdapter -InterfaceIndex $ip.InterfaceIndex -ErrorAction SilentlyContinue
        OK "$($ip.IPAddress)  ($($iface.Name))"
    }
    $primary = ($ips | Where-Object { $_.IPAddress -like "192.168.*" } | Select-Object -First 1)
    if (-not $primary) { $primary = ($ips | Select-Object -First 1) }
    if ($primary) {
        Write-Host ""
        Write-Host "  >>> Mac 侧 Join IP 填: $($primary.IPAddress):2456" -ForegroundColor Magenta
        Write-Host ""
    }
} else {
    Bad "未找到内网 IP"
}

# ---------- 防火墙 ----------
Head "防火墙"
$rules = Get-NetFirewallRule -DisplayName "Valheim LAN*" -ErrorAction SilentlyContinue
if ($rules) {
    foreach ($r in $rules) {
        $pf = $r | Get-NetFirewallPortFilter
        OK "$($r.DisplayName)  enabled=$($r.Enabled)  port=$($pf.LocalPort)  profile=$($r.Profile)"
    }
} else {
    Info "无 Valheim 规则（运行 03-firewall.ps1）"
}

# ---------- 端口 ----------
Head "端口 2456-2458"
$net = netstat -ano | Select-String "245[678]"
if ($net) { $net | ForEach-Object { Info $_.ToString().Trim() } } else { Info "无监听（游戏未启动）" }

# ---------- 汇总 ----------
Line
Write-Host "下一步:" -ForegroundColor White
Write-Host "  1. 完全退出 Steam" -ForegroundColor Gray
Write-Host "  2. 02-apply-goldberg.ps1" -ForegroundColor Gray
Write-Host "  3. 03-firewall.ps1" -ForegroundColor Gray
Write-Host "  4. 04-launch.ps1" -ForegroundColor Gray
Write-Host ""
