#!/usr/bin/env pwsh

param([string]$RootPath = $null, [switch]$FullScan)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== InstaFindCheats ===" -ForegroundColor Cyan

$rgExe = $null
foreach ($p in @("$env:LOCALAPPDATA\Programs\ripgrep\rg.exe", "$env:ProgramFiles\ripgrep\rg.exe", "$env:ProgramFiles(x86)\ripgrep\rg.exe")) { 
    if (Test-Path $p) { $rgExe = $p } 
}
if (-not $rgExe) { $rg = Get-Command rg -EA SilentlyContinue; if ($rg) { $rgExe = $rg.Source } }

if (-not $rgExe) {
    try {
        $tempZip = "$env:TEMP\rg.zip"; $installDir = "$env:LOCALAPPDATA\Programs\ripgrep"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-pc-windows-msvc.zip" -OutFile $tempZip -UseBasicParsing
        if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force }
        Expand-Archive -Path $tempZip -DestinationPath $installDir -Force
        $extracted = Get-ChildItem -Path $installDir -Filter "rg.exe" -Recurse | Select-Object -First 1
        if ($extracted) { Copy-Item $extracted.FullName -Destination "$installDir\rg.exe" -Force; Remove-Item $tempZip; $rgExe = "$installDir\rg.exe" }
    } catch { }
}

if (-not $rgExe) { Write-Host "Install manually: https://github.com/BurntSushi/ripgrep/releases"; exit 1 }

$Rules = @(
    @{ MinSize=9MB;  MaxSize=15MB;  Pattern='Gentee Launcher' },
    @{ MinSize=9MB;  MaxSize=16MB;  Pattern='X PROGRAMM LTD1' },
    @{ MinSize=16MB; MaxSize=24MB;  Pattern='7\+InZ\[\^0' },
    @{ MinSize=10MB; MaxSize=24MB;  Pattern='t\$PfD\)t\$PL' },
    @{ MinSize=4MB;  MaxSize=10MB;  Pattern='KDMapper' },
    @{ MinSize=0.3MB; MaxSize=3MB;  Pattern='DragonBurn' },
    @{ MinSize=2MB;  MaxSize=8MB;   Pattern='D:/Projects/touchskins' },
    @{ MinSize=43MB; MaxSize=60MB;  Pattern='vac_module_ok' },
    @{ MinSize=600MB; MaxSize=700MB; Pattern='SharkHack' },
    @{ MinSize=20MB; MaxSize=24MB;  Pattern='l\|rlK!tT1p' },
    @{ MinSize=15MB; MaxSize=24MB;  Pattern='MIDNIGHTLoader' },
    @{ MinSize=10MB; MaxSize=16MB;  Pattern='&Lp6U&XM\}3ZQ\*\^\[Hp\)' },
    @{ MinSize=2MB;  MaxSize=8MB;   Pattern='j_M6:F' },
    @{ MinSize=100KB; MaxSize=400KB; Pattern='swiftsoft' },
    @{ MinSize=20MB; MaxSize=24MB;  Pattern='exloader' },
    @{ MinSize=13MB; MaxSize=23MB;  Pattern='ZI>vZ@y#O%~' },
    @{ MinSize=200KB; MaxSize=400KB; Pattern='com.mvploader' },
    @{ MinSize=3MB;  MaxSize=7MB;   Pattern='Wzo8f9:GPd_C\[' }
)

$userProfile = $env:USERPROFILE

if ($FullScan) {
    Write-Host "FULL SCAN" -ForegroundColor Yellow
    $paths = @()
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object { $paths += $_.Root }
} else {
    Write-Host "FAST SCAN" -ForegroundColor Green
    $paths = @("$userProfile\Downloads", "$userProfile\Desktop", "$userProfile\Documents")
}

$results = @()

foreach ($path in $paths) {
    if (-not (Test-Path $path)) { continue }
    Write-Host "Scan: $path" -ForegroundColor Cyan
    
    foreach ($rule in $Rules) {
        Write-Host "  Searching: $($rule.Pattern)" -ForegroundColor Gray
        
        $output = & $rgExe -l --binary -j 8 $rule.Pattern $path 2>$null
        
        foreach ($file in $output) {
            if (-not (Test-Path $file)) { continue }
            if ($file -notmatch '\.exe$') { continue }
            
            $fi = [System.IO.FileInfo]::new($file)
            
            if ($fi.Length -lt $rule.MinSize -or $fi.Length -gt $rule.MaxSize) { continue }
            
            $exists = $results | Where-Object { $_.Path -eq $file }
            if (-not $exists) {
                $results += [PSCustomObject]@{
                    Name = $fi.Name
                    Path = $file
                    SizeMB = [math]::Round($fi.Length / 1MB, 2)
                    Rule = $rule.Pattern
                }
                Write-Host "    [FOUND] $($fi.Name) ($([math]::Round($fi.Length / 1MB, 2)) MB)" -ForegroundColor Green
            }
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