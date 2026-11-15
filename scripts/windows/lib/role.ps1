# 通用配置读取 — 供其它脚本 dot-source
# 用法: . "$PSScriptRoot\..\lib\role.ps1"

function Find-RepoRoot {
    param([string]$StartDir)
    $cur = $StartDir
    while ($cur) {
        if (Test-Path (Join-Path $cur ".git")) { return $cur }
        $parent = Split-Path $cur -Parent
        if ($parent -eq $cur -or -not $parent) { break }
        $cur = $parent
    }
    return $null
}

function Get-RoleConfig {
    param([string]$RepoDir)

    $result = @{
        HostRole    = "mac"                        # 默认 Mac 主机
        HostName    = "PlayerA"
        HostSteamId = "76561198000000001"
        ClientName  = "PlayerB"
        ClientSteamId = "76561198000000002"
        Port        = 2456
        Source      = "default"
    }

    if (-not $RepoDir) { $RepoDir = Find-RepoRoot -StartDir $PSScriptRoot }
    $roleFile = if ($RepoDir) { Join-Path $RepoDir "config\role.conf" } else { $null }

    if ($roleFile -and (Test-Path $roleFile)) {
        $content = Get-Content $roleFile -Raw
        if ($content -match "(?m)^\s*HOST_ROLE\s*=\s*(\w+)")     { $result.HostRole      = $Matches[1].Trim() }
        if ($content -match "(?m)^\s*HOST_NAME\s*=\s*(\S+)")     { $result.HostName      = $Matches[1].Trim() }
        if ($content -match "(?m)^\s*HOST_STEAMID\s*=\s*(\d+)")  { $result.HostSteamId   = $Matches[1].Trim() }
        if ($content -match "(?m)^\s*CLIENT_NAME\s*=\s*(\S+)")   { $result.ClientName    = $Matches[1].Trim() }
        if ($content -match "(?m)^\s*CLIENT_STEAMID\s*=\s*(\d+)"){ $result.ClientSteamId = $Matches[1].Trim() }
        if ($content -match "(?m)^\s*PORT\s*=\s*(\d+)")          { $result.Port          = [int]$Matches[1] }
        $result.Source = $roleFile
    }

    return $result
}

function Get-ThisMachineRole {
    param([string]$RepoDir)
    $cfg = Get-RoleConfig -RepoDir $RepoDir
    # 本脚本在 windows/ 下，所以本机是 Windows
    if ($cfg.HostRole -eq "windows") { return "host" } else { return "client" }
}

function Get-MyIdentity {
    param([string]$RepoDir)
    $cfg = Get-RoleConfig -RepoDir $RepoDir
    if ($cfg.HostRole -eq "windows") {
        return @{ Name = $cfg.HostName; SteamId = $cfg.HostSteamId; Role = "host" }
    } else {
        return @{ Name = $cfg.ClientName; SteamId = $cfg.ClientSteamId; Role = "client" }
    }
}
