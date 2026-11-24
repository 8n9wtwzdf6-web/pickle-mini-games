#Requires -Version 5.1
<#
    Pickle Agent Bridge
    ------------------------------------------------------------
    · 15초마다 GitHub(pickle-mini-games)의 main 브랜치를 확인합니다.
    · 새 커밋이 있으면 PC의 게임 폴더(기본 C:\PickleGames)로 자동으로 받아옵니다.
    · Discord 웹훅을 설정해 두면 휴대폰 Discord 채널로 업데이트 알림이 갑니다.
    · 중지하려면 이 창에서 Ctrl + C 를 누르세요.
    · 안전 원칙: PC에서 고친 파일과 PC에서 만든 커밋은 지우거나 덮어쓰지 않습니다.
      (빠른 감기(fast-forward)로만 받아옵니다.)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# git 이 아이디를 물어보며 창을 멈춰 세우지 않도록 (자동 실행용)
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_INTERACTIVE     = 'never'

# ------------------------------------------------------------
# 기본 설정
# ------------------------------------------------------------
$Script:RepoUrl     = 'https://github.com/8n9wtwzdf6-web/pickle-mini-games.git'
$Script:RepoWebUrl  = 'https://github.com/8n9wtwzdf6-web/pickle-mini-games'
$Script:Branch      = 'main'
$Script:IntervalSec = 15
$Script:DefaultRoot = 'C:\PickleGames'
$Script:WorkFolder  = $Script:DefaultRoot
$Script:Webhook     = ''
$Script:Cycle       = 0
$Script:FailCount   = 0
$Script:LastExit    = 0
$Script:LastNotice  = ''

if ($PSScriptRoot) {
    $Script:ScriptDir = $PSScriptRoot
} else {
    $Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if ([string]::IsNullOrWhiteSpace($Script:ScriptDir)) { $Script:ScriptDir = (Get-Location).Path }
$Script:ConfigPath = Join-Path $Script:ScriptDir 'config.json'

# ------------------------------------------------------------
# 콘솔 한글 출력 설정
# ------------------------------------------------------------
try {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [Console]::OutputEncoding = $utf8
    $OutputEncoding           = $utf8
} catch { }

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

# ------------------------------------------------------------
# 출력 도우미 (콘솔 깨짐을 피하려고 기호는 ASCII 로)
# ------------------------------------------------------------
function Write-Line {
    param([string]$Text = '')
    Write-Host $Text
}
function Write-Step {
    param([string]$Text)
    Write-Host ("   - " + $Text)
}
function Write-Ok {
    param([string]$Text)
    Write-Host ("   [OK] " + $Text) -ForegroundColor Green
}
function Write-Note {
    param([string]$Text)
    Write-Host ("   [i] " + $Text) -ForegroundColor Gray
}
function Write-Warn2 {
    param([string]$Text)
    Write-Host ("   [!] " + $Text) -ForegroundColor Yellow
}
function Write-Err2 {
    param([string]$Text)
    Write-Host ("   [x] " + $Text) -ForegroundColor Red
}
function Write-Rule {
    Write-Host ('   ' + ('-' * 62)) -ForegroundColor DarkGray
}

function Normalize-FolderPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $p = $Path.Trim().Trim([char]34).Trim([char]39)
    if ($p.Length -gt 3) { $p = $p.TrimEnd([char]92) }
    return $p
}

function ConvertTo-Lines {
    param($Value)
    if ($null -eq $Value) { return @() }
    $text = ((@($Value) | ForEach-Object { "$_" }) -join "`n")
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    return @($text -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -ne '' })
}

# ------------------------------------------------------------
# git 실행 도우미
# ------------------------------------------------------------
function Get-GitVersionText {
    try {
        $v = & git --version 2>&1
        return (ConvertTo-Lines $v | Select-Object -First 1)
    } catch {
        return ''
    }
}

function Invoke-Git {
    param([string[]]$GitArgs)
    $Script:LastExit = 0
    $out = & git -C $Script:WorkFolder @GitArgs 2>&1
    $Script:LastExit = $LASTEXITCODE
    return (ConvertTo-Lines $out)
}

function Get-GitText {
    param([string[]]$GitArgs)
    $lines = Invoke-Git -GitArgs $GitArgs
    if ($null -eq $lines) { return '' }
    return ((@($lines)) -join "`n").Trim()
}

function Get-ErrorText {
    param($Lines, [string]$What)
    $msg = (@($Lines) | Select-Object -First 3 | ForEach-Object { "$_" }) -join ' / '
    if ([string]::IsNullOrWhiteSpace($msg)) { $msg = $What + ' 실패' }
    return $msg
}

# ------------------------------------------------------------
# 설정 파일 (config.json) — 이 PC 안에만 저장됩니다
# ------------------------------------------------------------
function Read-AgentConfig {
    if (-not (Test-Path -LiteralPath $Script:ConfigPath)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $Script:ConfigPath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        $raw = $raw.TrimStart([char]0xFEFF)
        return ($raw | ConvertFrom-Json)
    } catch {
        Write-Warn2 'config.json 을 읽지 못했습니다. 기본 설정으로 계속합니다.'
        return $null
    }
}

function Save-AgentConfig {
    $obj = [ordered]@{
        discordWebhookUrl = $Script:Webhook
        workFolder        = $Script:WorkFolder
        repository        = $Script:RepoWebUrl
        savedAt           = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    try {
        ($obj | ConvertTo-Json) | Set-Content -LiteralPath $Script:ConfigPath -Encoding UTF8
        return $true
    } catch {
        Write-Warn2 ("config.json 을 저장하지 못했습니다: " + $_.Exception.Message)
        return $false
    }
}

function Test-WebhookUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    return ($Url -match '^https://[A-Za-z0-9.\-]*discord(app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9._\-]+')
}

function Send-Discord {
    param([string]$Content)
    if (-not (Test-WebhookUrl $Script:Webhook)) { return $false }
    try {
        # 폰 Discord 알림 설정이 기본값이어도 푸시 배너가 뜨도록 @everyone 멘션을 붙입니다.
        $payload = @{
            content          = ('@everyone ' + $Content)
            allowed_mentions = @{ parse = @('everyone') }
        } | ConvertTo-Json -Compress -Depth 4
        $bytes   = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $resp = Invoke-RestMethod -Uri $Script:Webhook -Method Post -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 20
        if ($null -ne $resp -and $resp.PSObject.Properties.Name -contains 'code') {
            Write-Warn2 ('Discord 알림이 거부되었습니다: ' + $resp.message)
            return $false
        }
        return $true
    } catch {
        Write-Warn2 ('Discord 알림을 보내지 못했습니다: ' + $_.Exception.Message)
        return $false
    }
}

# ------------------------------------------------------------
# 화면
# ------------------------------------------------------------
function Show-Banner {
    Write-Line ''
    Write-Host '   ==============================================================' -ForegroundColor Cyan
    Write-Host '    Pickle Agent  ·  GitHub -> PC 자동 동기화 브릿지' -ForegroundColor Cyan
    Write-Host '   ==============================================================' -ForegroundColor Cyan
    Write-Line '    새 게임이 올라오면 15초 안에 노트북이 알아서 받아옵니다.'
    Write-Line ''
}

function Show-Summary {
    Write-Rule
    Write-Host '   지금부터 이 창은 계속 켜 두시면 됩니다.' -ForegroundColor White
    Write-Note  ('게임 폴더   : ' + $Script:WorkFolder)
    Write-Note  ('저장소      : ' + $Script:RepoWebUrl)
    if (Test-WebhookUrl $Script:Webhook) {
        Write-Note '휴대폰 알림 : Discord 연결됨'
    } else {
        Write-Note '휴대폰 알림 : 설정 안 됨 (README 2단계에서 추가할 수 있습니다)'
    }
    Write-Note  ('확인 주기   : ' + $Script:IntervalSec + '초마다')
    Write-Note  '중지하려면  : Ctrl + C'
    Write-Rule
    Write-Line ''
}

# ------------------------------------------------------------
# 1) 사전 확인
# ------------------------------------------------------------
function Test-GitAvailable {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Line ''
        Write-Err2 'git 이 설치되어 있지 않습니다. (게임을 받아오는 데 꼭 필요합니다)'
        Write-Line ''
        Write-Line '   ▶ 아래 한 줄을 복사해서 이 창에 붙여넣고 엔터를 누르면 자동 설치됩니다.'
        Write-Line ''
        Write-Host '     winget install --id Git.Git -e --source winget' -ForegroundColor White
        Write-Line ''
        Write-Line '   ▶ 위 명령이 안 되면 이 주소에서 "Windows" 설치 파일을 받아 실행하세요.'
        Write-Line '     https://git-scm.com/download/win'
        Write-Line ''
        Write-Line '   설치가 끝나면 이 창을 닫고 Start_Pickle_Agent.bat 을 다시 더블클릭하세요.'
        return $false
    }
    Write-Ok ('git 확인됨  (' + (Get-GitVersionText) + ')')
    return $true
}

# ------------------------------------------------------------
# 2) 첫 실행 설정
# ------------------------------------------------------------
function Read-FirstTimeSettings {
    Write-Line ''
    Write-Rule
    Write-Host '   첫 실행 설정 (이번 한 번만 물어봅니다)' -ForegroundColor White
    Write-Rule

    Write-Line ''
    Write-Line '   게임 폴더를 둘 위치를 정합니다. 그냥 엔터를 누르면 기본값을 씁니다.'
    Write-Note ('기본값: ' + $Script:DefaultRoot)
    $folder = Read-Host '   폴더 경로'
    if (-not [string]::IsNullOrWhiteSpace($folder)) {
        $Script:WorkFolder = Normalize-FolderPath $folder
    }
    if ([string]::IsNullOrWhiteSpace($Script:WorkFolder)) { $Script:WorkFolder = $Script:DefaultRoot }
    Write-Note ('-> ' + $Script:WorkFolder)

    Write-Line ''
    Write-Line '   휴대폰 Discord 로 업데이트 알림을 받으려면 웹훅 URL 을 붙여넣으세요.'
    Write-Line '   (모르면 그냥 엔터 — 나중에 config.json 에서 추가할 수 있습니다)'
    Write-Note '받는 법: Discord 채널 톱니바퀴 -> 연동(Integrations) -> 웹후크 -> 새 웹후크 -> 웹후크 URL 복사'

    $tries = 0
    while ($tries -lt 3) {
        $tries++
        $url = Read-Host '   Discord 웹훅 URL'
        if ([string]::IsNullOrWhiteSpace($url)) {
            $Script:Webhook = ''
            Write-Note 'Discord 알림 없이 진행합니다.'
            break
        }
        $url = $url.Trim().Trim([char]34).Trim([char]39)
        if (Test-WebhookUrl $url) {
            $Script:Webhook = $url
            Write-Ok 'Discord 웹훅 주소 형식 확인됨'
            break
        }
        Write-Warn2 '주소 형식이 맞지 않는 것 같습니다. (https://discord.com/api/webhooks/... 형태여야 합니다)'
        if ($tries -ge 3) {
            $Script:Webhook = ''
            Write-Note 'Discord 알림 없이 진행합니다. 나중에 config.json 에서 고칠 수 있습니다.'
        }
    }

    [void](Save-AgentConfig)
    Write-Line ''
    Write-Ok ('설정을 저장했습니다: ' + $Script:ConfigPath)

    if (Test-WebhookUrl $Script:Webhook) {
        Write-Step 'Discord 로 연결 확인 메시지를 보내는 중…'
        $hello = '🔗 **Pickle Agent 연결 완료**' + "`n" + '이제 노트북이 GitHub 의 새 게임·업데이트를 받아올 때마다 이 채널로 알려 드립니다.'
        if (Send-Discord $hello) { Write-Ok 'Discord 연결 확인 메시지를 보냈습니다. 휴대폰을 확인해 보세요.' }
    }
    Write-Line ''
}

function Initialize-Settings {
    $cfg = Read-AgentConfig
    if ($null -eq $cfg) {
        Read-FirstTimeSettings
        return
    }
    $names = @($cfg.PSObject.Properties.Name)
    if ($names -contains 'workFolder' -and -not [string]::IsNullOrWhiteSpace([string]$cfg.workFolder)) {
        $Script:WorkFolder = Normalize-FolderPath ([string]$cfg.workFolder)
    }
    if ($names -contains 'discordWebhookUrl') {
        $Script:Webhook = ([string]$cfg.discordWebhookUrl).Trim()
    }
    Write-Note ('기존 설정을 불러왔습니다: ' + $Script:ConfigPath)
    if (-not [string]::IsNullOrWhiteSpace($Script:Webhook) -and -not (Test-WebhookUrl $Script:Webhook)) {
        Write-Warn2 'config.json 의 Discord 웹훅 주소 형식이 이상합니다. 알림 없이 진행합니다.'
        $Script:Webhook = ''
    }
}

# ------------------------------------------------------------
# 3) 저장소 준비 (없으면 clone)
# ------------------------------------------------------------
function Initialize-Repository {
    if (-not (Test-Path -LiteralPath $Script:WorkFolder)) {
        try {
            New-Item -ItemType Directory -Path $Script:WorkFolder -Force | Out-Null
        } catch {
            Write-Err2 ('폴더를 만들지 못했습니다: ' + $Script:WorkFolder)
            Write-Note  ('관리자 권한이 필요할 수 있습니다. 다른 위치(예: D:\PickleGames)를 골라 다시 실행해 주세요.')
            return $false
        }
    }

    $gitDir = Join-Path $Script:WorkFolder '.git'
    if (Test-Path -LiteralPath $gitDir) {
        $cur = Get-GitText @('rev-parse', '--abbrev-ref', 'HEAD')
        if (-not [string]::IsNullOrWhiteSpace($cur) -and $cur -ne $Script:Branch) {
            Write-Warn2 ("현재 브랜치가 '" + $cur + "' 입니다. '" + $Script:Branch + "' 로 바꿉니다.")
            [void](Invoke-Git @('checkout', $Script:Branch))
        }
        $remote = Get-GitText @('remote', 'get-url', 'origin')
        if ([string]::IsNullOrWhiteSpace($remote)) {
            [void](Invoke-Git @('remote', 'add', 'origin', $Script:RepoUrl))
        } elseif ($remote -ne $Script:RepoUrl) {
            Write-Note ('origin 주소: ' + $remote)
        }
        [void](Invoke-Git @('config', 'core.quotepath', 'false'))
        Write-Ok ('이미 받아 둔 게임 폴더가 있습니다: ' + $Script:WorkFolder)
        return $true
    }

    $items = @()
    try { $items = @(Get-ChildItem -LiteralPath $Script:WorkFolder -Force -ErrorAction Stop) } catch { }
    if ($items.Count -gt 0) {
        Write-Err2 ('폴더는 있는데 git 저장소가 아닙니다: ' + $Script:WorkFolder)
        Write-Note '폴더 이름을 바꾸거나 비운 뒤 다시 실행해 주세요. (이 스크립트는 파일을 지우지 않습니다)'
        return $false
    }

    Write-Step ('처음으로 게임 폴더를 내려받습니다… (' + $Script:WorkFolder + ')')
    Write-Note  '처음 한 번은 1~2분쯤 걸릴 수 있습니다.'
    $out = & git clone --branch $Script:Branch $Script:RepoUrl $Script:WorkFolder 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Err2 '내려받기에 실패했습니다.'
        foreach ($l in (ConvertTo-Lines $out)) { Write-Note $l }
        Write-Note '인터넷 연결을 확인한 뒤 다시 실행해 주세요.'
        return $false
    }
    [void](Invoke-Git @('config', 'core.quotepath', 'false'))
    Write-Ok '게임 폴더 준비 완료'
    Write-Note ('roblox 게임 폴더: ' + $Script:WorkFolder + '\roblox-*')
    return $true
}

# ------------------------------------------------------------
# 4) 한 번 확인 (fetch -> 비교 -> pull -> 보고 만들기)
# ------------------------------------------------------------
function Get-CommitInfo {
    param([string]$OldHead, [string]$NewHead)
    $range = $OldHead + '..' + $NewHead
    $sep   = [char]31
    $fmt   = '--pretty=format:%H' + $sep + '%h' + $sep + '%an' + $sep + '%s'
    $raw   = Get-GitText @('log', $fmt, $range)
    $list  = New-Object System.Collections.ArrayList
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        foreach ($line in ($raw -split "`n")) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $p = $line -split ([char]31)
            if ($p.Count -lt 3) { continue }
            $subject = ''
            if ($p.Count -ge 4) { $subject = (($p[3..($p.Count - 1)]) -join $sep) }
            [void]$list.Add([pscustomobject]@{
                Hash    = $p[0]
                Short   = $p[1]
                Author  = $p[2]
                Subject = $subject
            })
        }
    }
    return @($list)
}

function Get-CommitFiles {
    param([string]$Hash)
    $lines = Invoke-Git -GitArgs @('show', '--name-only', '--pretty=format:', $Hash)
    return @($lines | Where-Object { $_ -ne '' })
}

function Invoke-UpdateCheck {
    $fetch = Invoke-Git -GitArgs @('fetch', 'origin', $Script:Branch, '--quiet')
    if ($Script:LastExit -ne 0) {
        throw (Get-ErrorText $fetch 'git fetch') 
    }

    $local  = Get-GitText @('rev-parse', 'HEAD')
    $remote = Get-GitText @('rev-parse', ('origin/' + $Script:Branch))
    if ($local -eq $remote) { return $null }

    # PC 에서 직접 고친 파일이 있으면 건드리지 않습니다
    $dirty = Get-GitText @('status', '--porcelain', '--untracked-files=no')
    if (-not [string]::IsNullOrWhiteSpace($dirty)) {
        return [pscustomobject]@{
            Kind    = 'skip'
            Message = 'PC 에서 직접 고친 파일이 있어 자동 업데이트를 건너뜁니다. (고친 내용을 커밋하거나 되돌리면 다시 받아옵니다)'
        }
    }

    [void](Invoke-Git -GitArgs @('merge-base', '--is-ancestor', 'HEAD', ('origin/' + $Script:Branch)))
    if ($Script:LastExit -ne 0) {
        return [pscustomobject]@{
            Kind    = 'skip'
            Message = 'PC 에만 있는 커밋이 있어 자동으로 합치지 않았습니다. (PC 커밋을 push 하면 자동으로 이어집니다)'
        }
    }

    $pullOut = Invoke-Git -GitArgs @('pull', '--ff-only', 'origin', $Script:Branch)
    if ($Script:LastExit -ne 0) {
        throw (Get-ErrorText $pullOut 'git pull')
    }

    $newHead = Get-GitText @('rev-parse', 'HEAD')
    if ($newHead -eq $local) { return $null }

    $commits = Get-CommitInfo -OldHead $local -NewHead $newHead
    $allFiles = Invoke-Git -GitArgs @('diff', '--name-only', $local, $newHead)
    $allFiles = @($allFiles | Where-Object { $_ -ne '' })

    $roblox = New-Object System.Collections.ArrayList
    foreach ($f in $allFiles) {
        if ($f -match '^(roblox-[^/]+)/') {
            $folderName = $matches[1]
            if (-not ($roblox -contains $folderName)) { [void]$roblox.Add($folderName) }
        }
    }

    return [pscustomobject]@{
        Kind       = 'update'
        OldHead    = $local
        NewHead    = $newHead
        Commits    = $commits
        Files      = $allFiles
        Roblox     = @($roblox)
        Time       = (Get-Date -Format 'MM-dd HH:mm:ss')
    }
}

# ------------------------------------------------------------
# 5) 화면 출력 + Discord 메시지
# ------------------------------------------------------------
function Show-UpdateReport {
    param($Info)
    $count = @($Info.Commits).Count
    $time  = $Info.Time

    Write-Line ''
    Write-Rule
    Write-Host ('   [업데이트] ' + $time + '  ·  새 커밋 ' + $count + '건  ·  파일 ' + @($Info.Files).Count + '개') -ForegroundColor Cyan
    Write-Rule

    $idx = 0
    foreach ($c in (@($Info.Commits) | Select-Object -First 5)) {
        $idx++
        Write-Host ('   ' + $idx + ') ' + $c.Short + '  ' + $c.Subject) -ForegroundColor White
        $files = Get-CommitFiles -Hash $c.Hash
        $shown = @($files | Select-Object -First 4)
        Write-Note ('작성자 ' + $c.Author + ' · 파일 ' + @($files).Count + '개')
        foreach ($f in $shown) { Write-Host ('        ' + $f) -ForegroundColor DarkGray }
        if (@($files).Count -gt $shown.Count) {
            Write-Host ('        ... 외 ' + (@($files).Count - $shown.Count) + '개') -ForegroundColor DarkGray
        }
    }
    if ($count -gt 5) { Write-Note ('... 그 밖에 ' + ($count - 5) + '건 더 있습니다.') }

    if (@($Info.Roblox).Count -gt 0) {
        Write-Line ''
        Write-Host '   [게임] 로블록스 스크립트가 업데이트되었습니다.' -ForegroundColor Magenta
        foreach ($r in @($Info.Roblox)) {
            Write-Host ('        ' + $Script:WorkFolder + '\' + $r + '  폴더 확인') -ForegroundColor Magenta
        }
        Write-Note 'Roblox Studio 에서 열어 확인하고 Publish 하면 됩니다.'
    }
    Write-Rule

    if (Test-WebhookUrl $Script:Webhook) {
        if (Send-Discord (Build-DiscordMessage -Info $Info)) {
            Write-Ok '휴대폰 Discord 로 알림을 보냈습니다.'
        }
    }
    Write-Line ''
}

function Build-DiscordMessage {
    param($Info)
    $count = @($Info.Commits).Count
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('🎮 **Pickle 게임 업데이트** — 노트북에 자동 반영 완료')
    [void]$lines.Add('`' + $Info.Time + '` · 새 커밋 ' + $count + '건')

    $idx = 0
    foreach ($c in (@($Info.Commits) | Select-Object -First 5)) {
        $idx++
        [void]$lines.Add('')
        [void]$lines.Add('**' + $idx + '.** ' + $c.Subject)
        [void]$lines.Add('`' + $c.Short + '` · ' + $c.Author)
    }
    if ($count -gt 5) { [void]$lines.Add('... 외 ' + ($count - 5) + '건') }

    if (@($Info.Roblox).Count -gt 0) {
        [void]$lines.Add('')
        $folders = (@($Info.Roblox) | ForEach-Object { '`' + $Script:WorkFolder + '\' + $_ + '`' }) -join ', '
        [void]$lines.Add('🎯 로블록스 폴더: ' + $folders)
    }
    [void]$lines.Add('')
    [void]$lines.Add('📁 받은 위치: `' + $Script:WorkFolder + '`')
    [void]$lines.Add('<' + $Script:RepoWebUrl + '>')

    $text = ($lines -join "`n")
    if ($text.Length -gt 1900) { $text = $text.Substring(0, 1900) + "`n... (생략)" }
    return $text
}

# ------------------------------------------------------------
# 6) 실행
# ------------------------------------------------------------
Show-Banner

if (-not (Test-GitAvailable)) {
    Write-Line ''
    Write-Line '   이 창을 닫으실 때는 아무 키나 누르세요.'
    exit 1
}

try {
    Initialize-Settings
} catch {
    Write-Warn2 ('설정 처리 중 문제가 있었습니다: ' + $_.Exception.Message)
    Write-Note  '기본 설정으로 계속합니다.'
}

if (-not (Initialize-Repository)) {
    Write-Line ''
    Write-Line '   이 창을 닫으실 때는 아무 키나 누르세요.'
    exit 1
}

Show-Summary

# 시작하자마자 한 번 확인 (밤사이 쌓인 커밋 바로 반영)
try {
    $first = Invoke-UpdateCheck
    if ($null -ne $first) {
        if ($first.Kind -eq 'update') { Show-UpdateReport -Info $first }
        elseif ($first.Kind -eq 'skip') { Write-Warn2 $first.Message; $Script:LastNotice = $first.Message }
    }
} catch {
    Write-Warn2 ('첫 확인에서 문제가 있었습니다: ' + $_.Exception.Message)
}

$startMessage = '🟢 **Pickle Agent 시작**' + "`n" + 'PC 가 ' + $Script:IntervalSec + '초마다 GitHub 를 확인합니다.' + "`n" + '폴더: `' + $Script:WorkFolder + '`'
if (Test-WebhookUrl $Script:Webhook) { [void](Send-Discord $startMessage) }

Write-Note ('감시를 시작합니다  ·  ' + (Get-Date -Format 'HH:mm:ss') + '  ·  Ctrl + C 로 중지')

while ($true) {
    Start-Sleep -Seconds $Script:IntervalSec
    $Script:Cycle++

    try {
        $info = Invoke-UpdateCheck
        if ($null -ne $info) {
            if ($info.Kind -eq 'update') {
                Show-UpdateReport -Info $info
                $Script:LastNotice = ''
            } elseif ($info.Kind -eq 'skip') {
                if ($Script:LastNotice -ne $info.Message) {
                    Write-Warn2 $info.Message
                    $Script:LastNotice = $info.Message
                }
            }
        }
        if ($Script:FailCount -gt 0) {
            Write-Ok '다시 연결되었습니다.'
            $Script:FailCount = 0
        }
        # 1분에 한 번은 살아 있다는 표시
        if (($Script:Cycle % 4) -eq 0) {
            $head = Get-GitText @('rev-parse', '--short', 'HEAD')
            Write-Note ('대기 중  ' + (Get-Date -Format 'HH:mm:ss') + '  ·  최신 커밋 ' + $head + '  ·  새 소식 없음')
        }
    } catch {
        $Script:FailCount++
        if ($Script:FailCount -eq 1 -or ($Script:FailCount % 20) -eq 0) {
            Write-Warn2 ('확인에 실패했습니다 (' + $Script:FailCount + '회): ' + $_.Exception.Message)
            Write-Note  '인터넷 연결을 확인해 주세요. 연결되면 자동으로 다시 이어집니다.'
            if ($Script:FailCount -eq 20) {
                Write-Note '계속 실패하면 창을 닫았다가 Start_Pickle_Agent.bat 을 다시 더블클릭하세요.'
            }
        }
    }
}
