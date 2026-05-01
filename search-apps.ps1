#!/usr/bin/env pwsh

param([string]$RootPath = $null)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== InstaFindCheats ===" -ForegroundColor Cyan

Write-Host "Looking for rg..." -ForegroundColor Yellow

$rgExe = $null
$rgPaths = @(
    "$env:LOCALAPPDATA\Programs\ripgrep\rg.exe",
    "$env:ProgramFiles\ripgrep\rg.exe",
    "$env:ProgramFiles(x86)\ripgrep\rg.exe",
    "$env:USERPROFILE\.cargo\bin\rg.exe"
)

foreach ($p in $rgPaths) { 
    if (Test-Path $p) { 
        $rgExe = $p 
        Write-Host "Found: $rgExe" -ForegroundColor Green
        break 
    } 
}

if (-not $rgExe) {
    $rg = Get-Command rg -ErrorAction SilentlyContinue
    if ($rg) { 
        $rgExe = $rg.Source 
        Write-Host "Found in PATH: $rgExe" -ForegroundColor Green
    }
}

if (-not $rgExe) {
    Write-Host "Installing rg..." -ForegroundColor Yellow
    $tempZip = "$env:TEMP\rg.zip"
    $installDir = "$env:LOCALAPPDATA\Programs\ripgrep"
    
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
            Write-Host "Installed: $rgExe" -ForegroundColor Green
        }
    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
    }
}

if (-not $rgExe) {
    Write-Host "`nInstall manually: https://github.com/BurntSushi/ripgrep/releases" -ForegroundColor Red
    exit 1
}

$Rules = @(
  @{ MinBytes = 9MB;  MaxBytes = 15MB; Pattern = 'Gentee Launcher' },
  @{ MinBytes = 9MB;  MaxBytes = 16MB; Pattern = 'X PROGRAMM LTD1' },
  @{ MinBytes = 16MB; MaxBytes = 24MB; Pattern = '7\+InZ\[\^0' },
  @{ MinBytes = 10MB; MaxBytes = 24MB; Pattern = 't\$PfD\)t\$PL' },
  @{ MinBytes = 4MB;  MaxBytes = 10MB; Pattern = 'KDMapper' },
  @{ MinBytes = 0.3MB; MaxBytes = 3MB; Pattern = 'DragonBurn' },
  @{ MinBytes = 2MB;  MaxBytes = 8MB; Pattern = 'D:/Projects/touchskins' },
  @{ MinBytes = 43MB; MaxBytes = 60MB; Pattern = 'vac_module_ok' },
  @{ MinBytes = 600MB;MaxBytes = 700MB; Pattern = 'SharkHack' },
  @{ MinBytes = 20MB; MaxBytes = 24MB; Pattern = 'l\|rlK!tT1p' },
  @{ MinBytes = 15MB; MaxBytes = 24MB; Pattern = 'MIDNIGHTLoader' },
  @{ MinBytes = 10MB; MaxBytes = 16MB; Pattern = '&Lp6U&XM\}3ZQ\*\^\[Hp\)' },
  @{ MinBytes = 2MB;  MaxBytes = 8MB; Pattern = 'j_M6:F' },
  @{ MinBytes = 100KB; MaxBytes = 400KB; Pattern = 'swiftsoft' },
  @{ MinBytes = 20MB; MaxBytes = 24MB; Pattern = 'exloader' },
  @{ MinBytes = 13MB; MaxBytes = 23MB; Pattern = 'ZI>vZ@y#O%~' },
  @{ MinBytes = 200KB; MaxBytes = 400KB; Pattern = 'com.mvploader' },
  @{ MinBytes = 3MB;  MaxBytes = 7MB; Pattern = 'Wzo8f9:GPd_C\[' }
)

$userProfile = $env:USERPROFILE
if ($RootPath) { 
    $paths = @($RootPath) 
} else {
    $paths = @("$userProfile\Downloads", "$userProfile\Desktop", "$userProfile\Documents")
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object { $paths += $_.Root }
}

$results = @()

foreach ($path in $paths) {
    if (-not (Test-Path $path)) { continue }
    Write-Host "Scan: $path" -ForegroundColor Cyan
    
    foreach ($rule in $Rules) {
        $sizeFilter = "size:$([int]($rule.MinBytes / 1MB))-$([int]($rule.MaxBytes / 1MB))M"
        
        $output = & $rgExe -l --binary --max-count 1 -j 8 --size $sizeFilter $rule.Pattern $path 2>$null
        
        foreach ($file in $output) {
            if (-not (Test-Path $file)) { continue }
            if ($file -notmatch '\.exe$') { continue }
            
            $fi = [System.IO.FileInfo]::new($file)
            $size = $fi.Length
            
            if ($size -lt $rule.MinBytes -or $size -gt $rule.MaxBytes) { continue }
            
            $results += [PSCustomObject]@{ 
                Name = $fi.Name
                Path = $file
                SizeMB = [math]::Round($size / 1MB, 2)
                Rule = $rule.Pattern
            }
            Write-Host "  [FOUND] $($fi.Name) ($([math]::Round($size / 1MB, 2)) MB)" -ForegroundColor Green
        }
    }
}

if ($results.Count -eq 0) { 
    Write-Host "`nNo matches!" -ForegroundColor Yellow 
} else {
    $results = $results | Sort-Object Path -Unique
    Write-Host "`n=== $($results.Count) FOUND ===" -ForegroundColor Green
    $results | ForEach-Object { 
        Write-Host "$($_.Name) | $($_.Path) | $($_.SizeMB) MB | $($_.Rule)" -ForegroundColor Cyan 
    }
    
    $ch = Read-Host "`n[A] Open | [E] Export | [Q]"
    if ($ch -eq "A") { 
        $results | ForEach-Object { 
            Start-Process "explorer.exe" -ArgumentPath "/select,`"$($_.Path)`"" 
        } 
    }
    if ($ch -eq "E") { 
        $results | ForEach-Object { 
            "$($_.Path) | $($_.SizeMB) MB | $($_.Rule)" 
        } | Out-File "$env:USERPROFILE\Desktop\found.txt" -Encoding UTF8 
    }
}