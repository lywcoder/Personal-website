[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [string]$IdentityFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$siteDirectory = Join-Path $repositoryRoot 'personal-website'
$publisherPath = Join-Path $PSScriptRoot 'Publish-Website.sh'
$serverTarget = 'root@101.200.242.179'
$siteRoot = '/www/wwwroot/linyiweics.cn'

# Read UTF-8 explicitly so Windows PowerShell also handles the photo filename.
$html = Get-Content -LiteralPath (Join-Path $siteDirectory 'index.html') -Raw -Encoding UTF8
$photoName = [regex]::Match($html, '<img\s+[^>]*src="([^"]+\.jpg)"').Groups[1].Value
if (!$photoName -or $photoName -match '[/\\]' -or $photoName.StartsWith('.')) {
    throw 'Cannot identify a safe, local JPG profile photo in index.html.'
}
$siteFiles = @('index.html', '404.html', 'styles.css', 'script.js', 'forest-mist.png', $photoName)
$sourcePaths = @()
$manifestLines = @()
foreach ($fileName in $siteFiles) {
    $filePath = Join-Path $siteDirectory $fileName
    if (!(Test-Path -LiteralPath $filePath -PathType Leaf)) {
        throw "Missing website file: $filePath"
    }
    $sourcePaths += $filePath
    $hash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestLines += "$hash  $fileName"
}
foreach ($emailAddress in @('1390451354@qq.com', 'lin18601013891@gmail.com')) {
    if (!$html.Contains('href="mailto:' + $emailAddress + '"')) {
        throw "Missing contact link: $emailAddress"
    }
}
if (!(Test-Path -LiteralPath $publisherPath -PathType Leaf)) {
    throw "Missing remote publisher: $publisherPath"
}

Write-Host 'Local checks passed. These six public website files will be uploaded:'
$siteFiles | ForEach-Object { Write-Host "  $_" }
if ($CheckOnly) {
    Write-Host 'CheckOnly: no SSH connection, upload, or server change was made.'
    return
}

$sshPath = (Get-Command ssh.exe -CommandType Application -ErrorAction Stop).Source
$scpPath = (Get-Command scp.exe -CommandType Application -ErrorAction Stop).Source
$sshOptions = @('-p', '22', '-o', 'StrictHostKeyChecking=ask', '-o', 'ConnectTimeout=15')
$scpOptions = @('-P', '22', '-o', 'StrictHostKeyChecking=ask', '-o', 'ConnectTimeout=15')
if ($IdentityFile) {
    $identityPath = (Resolve-Path -LiteralPath $IdentityFile).Path
    $sshOptions += @('-i', $identityPath)
    $scpOptions += @('-i', $identityPath)
}

$deploymentId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$remoteStage = "/root/linyiweics-site-upload-$deploymentId"
$localStage = Join-Path ([IO.Path]::GetTempPath()) "linyiweics-deploy-$deploymentId"
$utf8 = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Path $localStage | Out-Null

try {
    $manifestPath = Join-Path $localStage 'sha256sum.txt'
    [IO.File]::WriteAllText($manifestPath, ($manifestLines -join "`n") + "`n", $utf8)
    $remoteScriptPath = Join-Path $localStage 'publish.sh'
    $remoteScript = [IO.File]::ReadAllText($publisherPath).Replace("`r`n", "`n")
    [IO.File]::WriteAllText($remoteScriptPath, $remoteScript, $utf8)

    Write-Host "Connecting to $serverTarget (SSH port 22)."
    Write-Host 'Enter your server password only at the SSH/SCP terminal prompt.'
    & $sshPath @sshOptions $serverTarget "test -d '$siteRoot' && mkdir -m 700 -- '$remoteStage'"
    if ($LASTEXITCODE -ne 0) {
        throw 'SSH preflight failed. Check login credentials, host fingerprint and website directory. No website files were replaced.'
    }

    Write-Host "Uploading to $remoteStage"
    $uploadPaths = $sourcePaths + @($manifestPath, $remoteScriptPath)
    & $scpPath @scpOptions @uploadPaths "${serverTarget}:$remoteStage/"
    if ($LASTEXITCODE -ne 0) {
        throw "Upload failed. Website files were not replaced. Staging directory: $remoteStage"
    }

    Write-Host 'Checking upload hashes, backing up the old site, then publishing.'
    & $sshPath @sshOptions $serverTarget "bash --noprofile --norc '$remoteStage/publish.sh' '$remoteStage'"
    if ($LASTEXITCODE -eq 2) {
        throw 'Website files were published and backed up, but public HTTPS homepage verification failed. Read the status, response and routing details above.'
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Publishing or HTTP verification failed. Read the backup/rollback instructions above. Server staging directory: $remoteStage"
    }
    Write-Host 'Publish command completed. Check the HTTPS result above and open https://linyiweics.cn in your browser.'
} finally {
    # Delete only the two generated local metadata files, never site files.
    foreach ($temporaryName in @('sha256sum.txt', 'publish.sh')) {
        $temporaryPath = Join-Path $localStage $temporaryName
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath
        }
    }
    if (Test-Path -LiteralPath $localStage -PathType Container) {
        Remove-Item -LiteralPath $localStage
    }
}
