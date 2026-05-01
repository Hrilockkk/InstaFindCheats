#!/usr/bin/env pwsh

param([string]$RootPath = $null)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-RipgrepPath {
  $rgPaths = @(
    "$env:LOCALAPPDATA\Programs\ripgrep\rg.exe",
    "$env:ProgramFiles\ripgrep\rg.exe",
    "$env:ProgramFiles(x86)\ripgrep\rg.exe",
    "$env:USERPROFILE\.cargo\bin\rg.exe"
  )
  foreach ($p in $rgPaths) { if (Test-Path $p) { return $p } }
  $rg = Get-Command rg -ErrorAction SilentlyContinue
  if ($rg) { return $rg.Source }
  return $null
}

function Install-Ripgrep {
  $rg = Get-RipgrepPath
  if ($rg) { Write-Host "Found: $rg" -ForegroundColor Green; return $true }
  
  Write-Host "Installing Ripgrep..." -ForegroundColor Yellow
  
  $tempZip = "$env:TEMP\ripgrep.zip"
  $installDir = "$env:LOCALAPPDATA\Programs\ripgrep"
  
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    Write-Host "Downloading..." -ForegroundColor Gray
    
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
    $webClient.DownloadFile("https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-pc-windows-msvc.zip", $tempZip)
    
    Write-Host "Extracting..." -ForegroundColor Gray
    
    if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
    Expand-Archive -Path $tempZip -DestinationPath $installDir -Force
    
    Write-Host "Finding rg.exe..." -ForegroundColor Gray
    
    $extractedRg = Get-ChildItem -Path $installDir -Filter "rg.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($extractedRg) {
      Write-Host "Copying to $installDir" -ForegroundColor Gray
      Copy-Item $extractedRg.FullName -Destination "$installDir\rg.exe" -Force
      
      $env:PATH = "$installDir;$env:PATH"
      [System.Environment]::SetEnvironmentVariable("PATH", "$installDir;$env:PATH", "User")
      
      Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
      
      Get-ChildItem -Path $installDir -Directory | ForEach-Object { 
        if ($_.Name -ne "rg.exe") { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue } 
      }
      
      Write-Host "Installed!" -ForegroundColor Green
      return $true
    }
  } catch {
    Write-Host "Error: $_" -ForegroundColor Red
  }
  return $false
}

Write-Host "=== InstaFindCheats ===" -ForegroundColor Cyan

$installed = Install-Ripgrep
$rgExe = Get-RipgrepPath

if (-not $rgExe) {
  Write-Host "`nFailed to install Ripgrep." -ForegroundColor Red
  Write-Host "Manual instructions:" -ForegroundColor Yellow
  Write-Host "  1. Open PowerShell as Admin" -ForegroundColor White
  Write-Host "  2. Run: winget install BurntSushi.ripgrep" -ForegroundColor White
  Write-Host "  3. Restart PowerShell" -ForegroundColor White
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
if ($RootPath) { $paths = @($RootPath) } else {
  $paths = @("$userProfile\Downloads", "$userProfile\Desktop", "$userProfile\Documents")
  Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object { $paths += $_.Root }
}

$results = @()
foreach ($path in $paths) {
  if (-not (Test-Path $path)) { continue }
  Write-Host "Scan: $path" -ForegroundColor Cyan
  foreach ($rule in $Rules) {
    $output = & $rgExe -l --binary --max-count 1 -j 8 $rule.Pattern $path 2>$null
    foreach ($file in $output) {
      if (-not (Test-Path $file)) { continue }
      if ($file -notmatch '\.exe$') { continue }
      $fi = [System.IO.FileInfo]::new($file)
      $size = $fi.Length
      if ($size -lt $rule.MinBytes -or $size -gt $rule.MaxBytes) { continue }
      $results += [PSCustomObject]@{ Name = $fi.Name; Path = $file; SizeMB = [math]::Round($size / 1MB, 2); Rule = $rule.Pattern }
      Write-Host "  [FOUND] $($fi.Name) ($([math]::Round($size / 1MB, 2)) MB)" -ForegroundColor Green
    }
  }
}

if ($results.Count -eq 0) { Write-Host "`nNo matches!" -ForegroundColor Yellow }
else {
  $results = $results | Sort-Object Path -Unique
  Write-Host "`n=== $($results.Count) FOUND ===" -ForegroundColor Green
  $results | ForEach-Object { Write-Host "$($_.Name) | $($_.Path) | $($_.SizeMB) MB" -ForegroundColor Cyan }
  $ch = Read-Host "`n[A] Open | [E] Export | [Q]"
  if ($ch -eq "A") { $results | ForEach-Object { Start-Process "explorer.exe" -ArgumentPath "/select,`"$($_.Path)`"" } }
  if ($ch -eq "E") { $results | ForEach-Object { "$($_.Path) | $($_.SizeMB) MB" } | Out-File "$env:USERPROFILE\Desktop\found.txt" -Encoding UTF8 }
}