#!/usr/bin/env pwsh

param([string]$RootPath = $null, [switch]$FullScan)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== InstaFindCheats ===" -ForegroundColor Cyan

$rgExe = $null
$rgPaths = @("$env:LOCALAPPDATA\Programs\ripgrep\rg.exe", "$env:ProgramFiles\ripgrep\rg.exe", "$env:ProgramFiles(x86)\ripgrep\rg.exe", "$env:USERPROFILE\.cargo\bin\rg.exe")

foreach ($p in $rgPaths) { if (Test-Path $p) { $rgExe = $p; break } }
if (-not $rgExe) { $rg = Get-Command rg -ErrorAction SilentlyContinue; if ($rg) { $rgExe = $rg.Source } }

if (-not $rgExe) {
    Write-Host "Installing rg..." -ForegroundColor Yellow
    $tempZip = "$env:TEMP\rg.zip"; $installDir = "$env:LOCALAPPDATA\Programs\ripgrep"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-pc-windows-msvc.zip" -OutFile $tempZip -UseBasicParsing
        if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
        Expand-Archive -Path $tempZip -DestinationPath $installDir -Force
        $extracted = Get-ChildItem -Path $installDir -Filter "rg.exe" -Recurse | Select-Object -First 1
        if ($extracted) {
            Copy-Item $extracted.FullName -Destination "$installDir\rg.exe" -Force
            Remove-Item $tempZip -Force
            $env:PATH = "$installDir;$env:PATH"
            [System.Environment]::SetEnvironmentVariable("PATH", "$installDir;$env:PATH", "User")
            $rgExe = "$installDir\rg.exe"
        }
    } catch { }
}

if (-not $rgExe) { Write-Host "Manual install: https://github.com/BurntSushi/ripgrep/releases"; exit 1 }

$Rules = @(
    @{ Min=9;   Max=15; Pattern='Gentee Launcher' },
    @{ Min=9;   Max=16; Pattern='X PROGRAMM LTD1' },
    @{ Min=16;  Max=24; Pattern='7\+InZ\[\^0' },
    @{ Min=10;  Max=24; Pattern='t\$PfD\)t\$PL' },
    @{ Min=4;   Max=10; Pattern='KDMapper' },
    @{ Min=0;   Max=3;  Pattern='DragonBurn' },
    @{ Min=2;   Max=8;  Pattern='D:/Projects/touchskins' },
    @{ Min=43;  Max=60; Pattern='vac_module_ok' },
    @{ Min=600; Max=700; Pattern='SharkHack' },
    @{ Min=20;  Max=24; Pattern='l\|rlK!tT1p' },
    @{ Min=15;  Max=24; Pattern='MIDNIGHTLoader' },
    @{ Min=10;  Max=16; Pattern='&Lp6U&XM\}3ZQ\*\^\[Hp\)' },
    @{ Min=2;   Max=8;  Pattern='j_M6:F' },
    @{ Min=0;   Max=0;  Pattern='swiftsoft' },
    @{ Min=20;  Max=24; Pattern='exloader' },
    @{ Min=13;  Max=23; Pattern='ZI>vZ@y#O%~' },
    @{ Min=0;   Max=0;  Pattern='com.mvploader' },
    @{ Min=3;   Max=7;  Pattern='Wzo8f9:GPd_C\[' }
)

$userProfile = $env:USERPROFILE

if ($FullScan) {
    Write-Host "FULL SCAN" -ForegroundColor Yellow
    $paths = @()
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object { $paths += $_.Root }
} else {
    Write-Host "FAST SCAN" -ForegroundColor Green
    $paths = @("$userProfile\Downloads", "$userProfile\Desktop", "$userProfile\Documents", "$userProfile\Videos")
}

$results = @()

foreach ($path in $paths) {
    if (-not (Test-Path $path)) { continue }
    Write-Host "Scan: $path" -ForegroundColor Cyan
    
    $minSize = 100kb
    $maxSize = 800mb
    
    $exeFiles = & $rgExe -l --size "${minSize}-${maxSize}M" -t exe --type-add 'exe=*.exe' $path 2>$null | Select-Object -First 5000
    
    Write-Host "  Found $($exeFiles.Count) exe by size" -ForegroundColor Gray
    
    foreach ($file in $exeFiles) {
        if (-not (Test-Path $file)) { continue }
        
        $fi = [System.IO.FileInfo]::new($file)
        $sizeMB = [math]::Round($fi.Length / 1MB, 0)
        
        foreach ($rule in $Rules) {
            if ($rule.Min -eq 0 -and $rule.Max -eq 0) { $ruleMin = 100kb; $ruleMax = 500kb }
            elseif ($rule.Min -eq 600) { $ruleMin = 600mb; $ruleMax = 700mb }
            else { $ruleMin = $rule.Min * 1MB; $ruleMax = $rule.Max * 1MB }
            
            if ($fi.Length -lt $ruleMin -or $fi.Length -gt $ruleMax) { continue }
            
            try {
                $fs = [System.IO.File]::OpenRead($file)
                $buf = New-Object byte[] 1MB
                $read = $fs.Read($buf, 0, $buf.Length)
                $fs.Close()
                
                $patternBytes = [System.Text.Encoding]::UTF8.GetBytes($rule.Pattern)
                
                for ($i = 0; $i -le $read - $patternBytes.Length; $i++) {
                    $found = $true
                    for ($j = 0; $j -lt $patternBytes.Length; $j++) {
                        if ($buf[$i + $j] -ne $patternBytes[$j]) { $found = $false; break }
                    }
                    if ($found) {
                        $exists = $results | Where-Object { $_.Path -eq $file }
                        if (-not $exists) {
                            $results += [PSCustomObject]@{ Name = $fi.Name; Path = $file; SizeMB = [math]::Round($fi.Length / 1MB, 2); Rule = $rule.Pattern }
                            Write-Host "    [FOUND] $($fi.Name) ($sizeMB MB)" -ForegroundColor Green
                        }
                        break
                    }
                }
            } catch { }
        }
    }
}

if ($results.Count -eq 0) { 
    Write-Host "`nNo matches!" -ForegroundColor Yellow
} else {
    Write-Host "`n=== $($results.Count) FOUND ===" -ForegroundColor Green
    $results | ForEach-Object { Write-Host "$($_.Name) | $($_.Path)" -ForegroundColor Cyan }
    
    $ch = Read-Host "`n[A] Open | [E] Export | [Q]"
    if ($ch -eq "A") { $results | ForEach-Object { Start-Process "explorer.exe" -ArgumentPath "/select,`"$($_.Path)`"" } }
    if ($ch -eq "E") { $results | ForEach-Object { "$($_.Path) | $($_.SizeMB) MB | $($_.Rule)" } | Out-File "$env:USERPROFILE\Desktop\found.txt" -Encoding UTF8 }
}