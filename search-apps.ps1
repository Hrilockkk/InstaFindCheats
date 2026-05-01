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
    @{ MinSize=9000KB; MaxSize=15000KB; Pattern='Gentee Launcher'; Literal=$true },
    @{ MinSize=9000KB; MaxSize=16000KB; Pattern='X PROGRAMM LTD1'; Literal=$true },
    @{ MinSize=16000KB; MaxSize=24000KB; Pattern='7+InZ[^0">'; Literal=$true },
    @{ MinSize=10000KB; MaxSize=24000KB; Pattern='t$PfD)t$PL'; Literal=$true },
    @{ MinSize=4000KB; MaxSize=10000KB; Pattern='KDMapper'; Literal=$true },
    @{ MinSize=300KB; MaxSize=3000KB; Pattern='DragonBurn'; Literal=$true },
    @{ MinSize=2000KB; MaxSize=8000KB; Pattern='D:/Projects/touchskins'; Literal=$true },
    @{ MinSize=43000KB; MaxSize=60000KB; Pattern='vac_module_ok'; Literal=$true },
    @{ MinSize=600000KB; MaxSize=700000KB; Pattern='SharkHack'; Literal=$true },
    @{ MinSize=20000KB; MaxSize=24000KB; Pattern='l|rlK!tT1p'; Literal=$true },
    @{ MinSize=15000KB; MaxSize=24000KB; Pattern='MIDNIGHTLoader'; Literal=$true },
    @{ MinSize=10000KB; MaxSize=16000KB; Pattern='&Lp6U&XM}3ZQ*^[Hp)'; Literal=$true },
    @{ MinSize=2000KB; MaxSize=8000KB; Pattern='j_M6:F>'; Literal=$true },
    @{ MinSize=100KB; MaxSize=400KB; Pattern='swiftsoft'; Literal=$true },
    @{ MinSize=20000KB; MaxSize=24000KB; Pattern='exloader'; Literal=$true },
    @{ MinSize=13000KB; MaxSize=23000KB; Pattern='ZI>vZ@y#O%~'; Literal=$true },
    @{ MinSize=200KB; MaxSize=400KB; Pattern='com.mvploader'; Literal=$true },
    @{ MinSize=3000KB; MaxSize=7000KB; Pattern='Wzo8f9:GPd_C['; Literal=$true }
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
        Write-Host "  Pattern: $($rule.Pattern)" -ForegroundColor Gray
        
        if ($rule.Literal) {
            $output = & $rgExe -l -F --binary -j 8 $rule.Pattern $path 2>$null
        } else {
            $output = & $rgExe -l --binary -j 8 $rule.Pattern $path 2>$null
        }
        
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