[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$KeepBrowserProfile,
    [switch]$KeepAgentBrowser,
    [switch]$SkipWsl
)

$ErrorActionPreference = "Stop"

$beginMarker = "# >>> navegador >>>"
$endMarker = "# <<< navegador <<<"

function Write-ReportLine {
    param(
        [string]$Label,
        [string]$Value
    )

    Write-Host ("{0}: {1}" -f $Label, $Value)
}

function Find-Command {
    param(
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command
        }
    }

    return $null
}

function Write-Utf8TextFile {
    param(
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Convert-WinPathToMnt {
    param(
        [string]$Path
    )

    $drive = $Path.Substring(0, 1).ToLower()
    $rest = $Path.Substring(2) -replace "\\", "/"
    return "/mnt/$drive$rest"
}

function Test-PathUnderDirectory {
    param(
        [string]$Path,
        [string]$BaseDirectory
    )

    $resolvedBase = [System.IO.Path]::GetFullPath($BaseDirectory).TrimEnd("\")
    $resolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
    return ($resolvedPath -eq $resolvedBase -or $resolvedPath.StartsWith($resolvedBase + "\", [System.StringComparison]::OrdinalIgnoreCase))
}

function Remove-DirectoryIfOwned {
    param(
        [string]$Path,
        [string]$BaseDirectory,
        [string]$Description,
        [System.Collections.IList]$Report
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $Report.Add("${Description}: nao encontrado") | Out-Null
        return
    }

    if (-not (Test-PathUnderDirectory -Path $Path -BaseDirectory $BaseDirectory)) {
        throw "Recusei remover '$Path' porque ele nao esta dentro de '$BaseDirectory'."
    }

    if ($PSCmdlet.ShouldProcess($Path, "Remove directory recursively")) {
        $lastError = $null
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                Remove-Item -LiteralPath $Path -Recurse -Force
                $Report.Add("${Description}: removido") | Out-Null
                return
            } catch {
                $lastError = $_
                Start-Sleep -Milliseconds 750
            }
        }

        throw $lastError
    }

    $Report.Add("${Description}: marcado para remocao") | Out-Null
}

function Remove-FileIfExists {
    param(
        [string]$Path,
        [string]$Description,
        [System.Collections.IList]$Report
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $Report.Add("${Description}: nao encontrado") | Out-Null
        return
    }

    if ($PSCmdlet.ShouldProcess($Path, "Remove file")) {
        Remove-Item -LiteralPath $Path -Force
        $Report.Add("${Description}: removido") | Out-Null
    } else {
        $Report.Add("${Description}: marcado para remocao") | Out-Null
    }
}

function Remove-NavegadorProfileBlock {
    param(
        [System.Collections.IList]$Report
    )

    if (-not (Test-Path -LiteralPath $PROFILE)) {
        $Report.Add("PowerShell profile: nao encontrado") | Out-Null
        return
    }

    $content = Get-Content -LiteralPath $PROFILE -Raw
    $pattern = "(?ms)\r?\n?$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?"

    if ($content -notmatch $pattern) {
        $Report.Add("PowerShell profile: bloco navegador nao encontrado") | Out-Null
        return
    }

    $newContent = [regex]::Replace($content, $pattern, "")
    if ($PSCmdlet.ShouldProcess($PROFILE, "Remove navegador function block")) {
        Write-Utf8TextFile -Path $PROFILE -Content $newContent
        $Report.Add("PowerShell profile: bloco navegador removido") | Out-Null
    } else {
        $Report.Add("PowerShell profile: bloco navegador marcado para remocao") | Out-Null
    }
}

function Stop-AgentBrowserDaemon {
    param(
        [System.Collections.IList]$Report
    )

    $agentBrowser = Find-Command -Names @("agent-browser", "agent-browser.cmd", "agent-browser.ps1")
    if (-not $agentBrowser) {
        $Report.Add("agent-browser daemon: comando nao encontrado") | Out-Null
        return
    }

    if ($PSCmdlet.ShouldProcess($agentBrowser.Source, "Close agent-browser daemon")) {
        try {
            & $agentBrowser.Source close 2>$null | Out-Null
            $Report.Add("agent-browser daemon: fechamento solicitado") | Out-Null
        } catch {
            $Report.Add("agent-browser daemon: falha ao fechar ($($_.Exception.Message))") | Out-Null
        }
    } else {
        $Report.Add("agent-browser daemon: fechamento marcado") | Out-Null
    }
}

function Stop-NavegadorChromeProcesses {
    param(
        [string]$ProfilePath,
        [System.Collections.IList]$Report
    )

    $chromeProcesses = @(Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" -ErrorAction SilentlyContinue)
    if ($chromeProcesses.Count -eq 0) {
        $Report.Add("Chrome do Navegador: nenhum processo encontrado") | Out-Null
        return
    }

    $matched = @(
        $chromeProcesses |
            Where-Object {
                $_.CommandLine -and $_.CommandLine.IndexOf($ProfilePath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            }
    )

    if ($matched.Count -eq 0) {
        $Report.Add("Chrome do Navegador: nenhum processo usando o perfil persistente") | Out-Null
        return
    }

    foreach ($process in $matched) {
        if ($PSCmdlet.ShouldProcess("chrome.exe PID $($process.ProcessId)", "Stop navegador Chrome process")) {
            try {
                Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
                $Report.Add("Chrome do Navegador: processo $($process.ProcessId) finalizado") | Out-Null
            } catch {
                $Report.Add("Chrome do Navegador: falha ao finalizar processo $($process.ProcessId) ($($_.Exception.Message))") | Out-Null
            }
        } else {
            $Report.Add("Chrome do Navegador: processo $($process.ProcessId) marcado para finalizacao") | Out-Null
        }
    }
}

function Uninstall-AgentBrowser {
    param(
        [System.Collections.IList]$Report
    )

    if ($KeepAgentBrowser) {
        $Report.Add("agent-browser npm: mantido por opcao") | Out-Null
        return
    }

    $npm = Find-Command -Names @("npm", "npm.cmd", "npm.exe")
    if (-not $npm) {
        $Report.Add("agent-browser npm: npm nao encontrado, desinstalacao ignorada") | Out-Null
        return
    }

    if (-not $PSCmdlet.ShouldProcess("agent-browser", "npm uninstall -g")) {
        $Report.Add("agent-browser npm: desinstalacao global marcada") | Out-Null
        return
    }

    $output = & $npm.Source uninstall -g agent-browser 2>&1
    if ($LASTEXITCODE -eq 0) {
        $Report.Add("agent-browser npm: desinstalacao global solicitada") | Out-Null
        return
    }

    $message = (($output | ForEach-Object { "$_" }) -join " | ").Trim()
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = "npm uninstall -g agent-browser retornou codigo $LASTEXITCODE"
    }

    throw $message
}

function Get-WslDistros {
    try {
        $null = wsl --status 2>$null
        if ($LASTEXITCODE -ne 0) {
            return @()
        }
    } catch {
        return @()
    }

    $encodingBefore = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    try {
        $distros = (wsl -l -q) -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and $_ -notmatch "^\s*$" }
    } finally {
        [Console]::OutputEncoding = $encodingBefore
    }

    return @($distros)
}

function Clear-NavegadorFromWsl {
    param(
        [System.Collections.IList]$Report
    )

    if ($SkipWsl) {
        $Report.Add("WSL: ignorado por opcao") | Out-Null
        return
    }

    $distros = Get-WslDistros
    if ($distros.Count -eq 0) {
        $Report.Add("WSL: nao detectado ou sem distros disponiveis") | Out-Null
        return
    }

    $cleanup = @'
#!/usr/bin/env bash
set -euo pipefail

BEGIN_MARK='# >>> navegador >>>'
END_MARK='# <<< navegador <<<'
BASHRC="$HOME/.bashrc"

rm -f "$HOME/.local/bin/navegador"
rm -rf "$HOME/.codex/skills/navegador"
rm -rf "$HOME/.claude/skills/navegador"

if [ -f "$BASHRC" ] && grep -qF "$BEGIN_MARK" "$BASHRC"; then
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
        index($0,b)==1 {skip=1; next}
        skip && index($0,e)==1 {skip=0; next}
        !skip {print}
    ' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
fi

if [ -f "$BASHRC" ]; then
    sed -i -E '/^EOF[[:space:]]*$/d' "$BASHRC"
fi
'@

    $cleanupWin = Join-Path $env:TEMP "navegador-uninstall-wsl.sh"
    Write-Utf8TextFile -Path $cleanupWin -Content ($cleanup -replace "`r`n", "`n")
    $cleanupLinux = Convert-WinPathToMnt -Path $cleanupWin

    try {
        foreach ($distro in $distros) {
            if ($PSCmdlet.ShouldProcess($distro, "Remove navegador artifacts from WSL")) {
                wsl -d $distro -- bash "$cleanupLinux" 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $Report.Add("WSL ${distro}: artefatos navegador removidos") | Out-Null
                } else {
                    $Report.Add("WSL ${distro}: falha ao remover artefatos") | Out-Null
                }
            } else {
                $Report.Add("WSL ${distro}: artefatos marcados para remocao") | Out-Null
            }
        }
    } finally {
        Remove-Item -LiteralPath $cleanupWin -Force -ErrorAction SilentlyContinue
    }
}

$removed = New-Object System.Collections.ArrayList

Write-Host "==> Fechando daemon do agent-browser"
Stop-AgentBrowserDaemon -Report $removed

Write-Host "==> Removendo funcao navegador do PowerShell"
Remove-NavegadorProfileBlock -Report $removed

Write-Host "==> Removendo atalho da area de trabalho"
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Navegador.lnk"
Remove-FileIfExists -Path $desktopShortcut -Description "Atalho da area de trabalho" -Report $removed

Write-Host "==> Removendo skills globais do Windows"
$codexSkill = Join-Path $env:USERPROFILE ".codex\skills\navegador"
$claudeSkill = Join-Path $env:USERPROFILE ".claude\skills\navegador"
Remove-DirectoryIfOwned -Path $codexSkill -BaseDirectory (Join-Path $env:USERPROFILE ".codex\skills") -Description "Skill Codex Windows" -Report $removed
Remove-DirectoryIfOwned -Path $claudeSkill -BaseDirectory (Join-Path $env:USERPROFILE ".claude\skills") -Description "Skill Claude Windows" -Report $removed

Write-Host "==> Removendo integracao WSL"
Clear-NavegadorFromWsl -Report $removed

Write-Host "==> Removendo perfil persistente do Navegador"
if ($KeepBrowserProfile) {
    $removed.Add("Perfil do Navegador: mantido por opcao") | Out-Null
} else {
    $browserProfile = Join-Path $env:USERPROFILE "Navegador"
    Stop-NavegadorChromeProcesses -ProfilePath $browserProfile -Report $removed
    Remove-DirectoryIfOwned -Path $browserProfile -BaseDirectory $env:USERPROFILE -Description "Perfil do Navegador" -Report $removed
}

Write-Host "==> Desinstalando agent-browser global"
Uninstall-AgentBrowser -Report $removed

Write-Host ""
Write-Host "=== Relatorio de desinstalacao - skill navegador ==="
$removed | ForEach-Object { Write-Host " - $_" }
Write-Host ""
Write-ReportLine -Label "Node.js" -Value "nao removido"
Write-ReportLine -Label "Google Chrome" -Value "nao removido"
Write-ReportLine -Label "Status geral" -Value "concluido"
Write-Host "Reinicie completamente o Codex e/ou Claude Code para descarregar a skill da sessao atual."
