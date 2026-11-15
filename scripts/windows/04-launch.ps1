# 04-launch.ps1 — 启动 Valheim（Goldberg 版，不走 Steam）
# 用法: powershell -ExecutionPolicy Bypass -File .\04-launch.ps1
#       powershell -ExecutionPolicy Bypass -File .\04-launch.ps1 -ValheimDir "D:\SteamLibrary\steamapps\common\Valheim"

[CmdletBinding()]
param(
    [string]$ValheimDir = "",
    [int]$Port = 2456,
    [switch]$NoConsole,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
function Line { Write-Host ("-" * 62) -ForegroundColor DarkGray }
function Head { param($t) Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }
function OK   { param($t) Write-Host "  [OK]   $t" -ForegroundColor Green }
function Warn { param($t) Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Bad  { param($t) Write-Host "  [FAIL] $t" -ForegroundColor Red }
function Info { param($t) Write-Host "         $t" -ForegroundColor Gray }

Write-Host ""
Write-Host "Valheim LAN Coop - 启动游戏（主机模式）" -ForegroundColor White
Line

# ---------- 定位 ----------
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
$exe = Join-Path $ValheimDir "valheim.exe"
if (-not (Test-Path $exe)) {
    Bad "找不到 valheim.exe。请用 -ValheimDir 指定"
    exit 1
}
OK "Valheim: $ValheimDir"

# ---------- 前置检查 ----------
Head "前置检查"

# 1. 补丁是否应用
$dll = Join-Path $ValheimDir "valheim_Data\Plugins\x86_64\steam_api64.dll"
$bak = "$dll.orig"
$ss  = Join-Path $ValheimDir "steam_settings"
if (-not (Test-Path $bak)) {
    Bad "未检测到补丁（缺 steam_api64.dll.orig）"
    Info "请先运行 02-apply-goldberg.ps1"
    if (-not $Force) { exit 1 }
}
if (-not (Test-Path (Join-Path $ss "configs.main.ini"))) {
    Bad "缺 steam_settings\configs.main.ini"
    Info "请先运行 02-apply-goldberg.ps1"
    if (-not $Force) { exit 1 }
}
$lanOk = Select-String -Path (Join-Path $ss "configs.main.ini") -Pattern "enable_lan_only\s*=\s*1"
if (-not $lanOk) {
    Bad "enable_lan_only 未设为 1（联机会失败）"
    if (-not $Force) { exit 1 }
} else {
    OK "enable_lan_only = 1"
}

# 2. Steam 是否运行
$sp = Get-Process steam -ErrorAction SilentlyContinue
if ($sp) {
    Warn "Steam 正在运行！"
    Warn "Steam 在线会校验授权，并可能顶掉 Mac 侧的同账号登录"
    $ans = Read-Host "  现在关闭 Steam? (Y/n)"
    if ($ans -ne "n") {
        Stop-Process -Name steam -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        if (Get-Process steam -ErrorAction SilentlyContinue) {
            Warn "Steam 仍在运行，请手动退出托盘图标"
        } else {
            OK "Steam 已关闭"
        }
    }
} else {
    OK "Steam 未运行"
}

# 3. 游戏是否已在运行
$vp = Get-Process valheim -ErrorAction SilentlyContinue | Select-Object -First 1
if ($vp) {
    Warn "valheim.exe 已在运行 (PID $($vp.Id))"
    $ans = Read-Host "  结束它并重启? (y/N)"
    if ($ans -eq "y") {
        Stop-Process -Id $vp.Id -Force
        Start-Sleep -Seconds 2
    } else {
        exit 0
    }
}

# 4. 端口占用
$portInUse = netstat -ano | Select-String ":$Port\s" | Select-String "UDP"
if ($portInUse) {
    Warn "端口 $Port 已被占用:"
    $portInUse | ForEach-Object { Info $_.ToString().Trim() }
    Info "换端口: -Port 2466"
}

# ---------- 启动 ----------
Head "启动"
$launchArgs = @()
if (-not $NoConsole) { $launchArgs += "-console" }
$launchArgs += "-port"
$launchArgs += "$Port"

Write-Host "  命令: `"$exe`" $($launchArgs -join ' ')" -ForegroundColor Gray
Write-Host ""

try {
    $proc = Start-Process -FilePath $exe -ArgumentList $launchArgs -WorkingDirectory $ValheimDir -PassThru
    Start-Sleep -Seconds 3
    if ($proc.HasExited) {
        Bad "进程启动后立即退出 (ExitCode=$($proc.ExitCode))"
        Info "常见原因："
        Info "  1. steam_api64.dll 放错位置"
        Info "  2. 缺 VC++ 运行库（装 vc_redist.x64.exe）"
        Info "  3. Goldberg 版本与游戏不兼容"
        exit 1
    }
    OK "已启动 (PID $($proc.Id))"
} catch {
    Bad "启动失败: $($_.Exception.Message)"
    exit 1
}

# ---------- 后续提示 ----------
Head "接下来"
Info "1. 游戏内 Start Game → 新建或选择世界"
Info "2. 必须真正进入世界，端口才开始监听"
Info "3. 进世界后按 F5 看控制台，确认无报错"
Write-Host ""
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -like "192.168.*" } |
       Select-Object -First 1).IPAddress
if (-not $ip) {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 |
           Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
           Select-Object -First 1).IPAddress
}
if ($ip) {
    Write-Host "  >>> 告诉 Mac 那台，Join IP 填: $ip`:$Port" -ForegroundColor Magenta
    Write-Host ""
}

# 等 10 秒后检查端口
Start-Sleep -Seconds 10
$listening = netstat -ano | Select-String ":$Port\s" | Select-String "UDP"
if ($listening) {
    OK "端口 $Port 已在监听"
} else {
    Info "端口 $Port 暂未监听 — 进入世界后才会监听，正常"
}

Line
Write-Host "游戏窗口应已打开。关闭本终端不影响游戏。" -ForegroundColor Gray
Write-Host ""
