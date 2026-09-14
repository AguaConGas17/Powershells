$ErrorActionPreference = "SilentlyContinue"
Clear-Host

function IsAdmin {
  $admin = [Security.Principal.WindowsBuiltInRole]::Administrator
  $current = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($current)

  return $principal.IsInRole($admin)
}

if (-not (IsAdmin)) {
  Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor White -BackgroundColor Red
  Start-Sleep -Seconds 5
  exit
}

Add-Type -TypeDefinition @"
// gracias diff goat 
using System;
using System.Text;
using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;

public class Kernel32 {
  [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
  public static extern uint QueryDosDevice(string lpDeviceName, StringBuilder lpTargetPath, uint ucchMax);
}

public class RegUtil
{
  [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
  public static extern int RegOpenKeyEx(
    UIntPtr hKey,
    string lpSubKey,
    uint ulOptions,
    int samDesired,
    out SafeRegistryHandle phkResult);

  [DllImport("advapi32.dll")]
  public static extern int RegQueryInfoKey(
    SafeRegistryHandle hKey,
    System.Text.StringBuilder lpClass,
    ref uint lpcClass,
    IntPtr lpReserved,
    out uint lpcSubKeys,
    out uint lpcbMaxSubKeyLen,
    out uint lpcbMaxClassLen,
    out uint lpcValues,
    out uint lpcbMaxValueNameLen,
    out uint lpcbMaxValueLen,
    out uint lpcbSecurityDescriptor,
    out long lpftLastWriteTime);

  public static DateTime GetLastWriteTime(string subKey)
  {
    SafeRegistryHandle hKey;

    RegOpenKeyEx((UIntPtr)0x80000002u, subKey, 0, 0x20019, out hKey);

    uint dummy = 0;
    long fileTime;
    RegQueryInfoKey(
      hKey,
      null,
      ref dummy,
      IntPtr.Zero,
      out dummy,
      out dummy,
      out dummy,
      out dummy,
      out dummy,
      out dummy,
      out dummy,
      out fileTime);

    return DateTime.FromFileTimeUtc(fileTime).ToLocalTime();
  }
}
"@

function Get-Drives {
  $max = 65536
  $stringBuilder = New-Object Text.StringBuilder($max)
  $driveMappings = Get-CimInstance Win32_Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
    $returnLength = [Kernel32]::QueryDosDevice($_.DriveLetter, $stringBuilder, $max)
    if ($returnLength) {
      @{
        DriveLetter = $_.DriveLetter
        DevicePath  = $stringBuilder.ToString()
        FileSystem  = $_.FileSystem
      }
    }
  }
  
  return $driveMappings
}
function Write-Int($indx, $simb, $message) {
  Write-Host $indx "[" -ForegroundColor $subtColor -NoNewline
  Write-Host $simb -ForegroundColor Yellow -NoNewline
  Write-Host "] " -ForegroundColor $subtColor -NoNewline
  
  Write-Host $message -ForegroundColor Yellow
}

$titleIndex = ("{0,1}" -f "")
$inforIndex = ("{0,2}" -f "")
$titleColor = "DarkMagenta"
$formatDate = "dd-MM-yyyy HH:mm:ss"
$currentDate = Get-Date
$textColor = "white"
$subtColor = "gray"

Write-Host "Script by " -NoNewline
Write-Host "aguacongas17 :)`n" -ForegroundColor Red

Write-Host "GENERAL INFORMATION" -ForegroundColor $titleColor

Write-Host $titleIndex "System boot time" -ForegroundColor $subtColor

$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$upTime = $currentDate - $bootTime
Write-Host $titleIndex " Last Boot:" -ForegroundColor $textColor -NoNewline
Write-Host " $bootTime " -ForegroundColor Green -NoNewline
Write-Host ("({0}d {1}h {2}m {3}s)" -f $upTime.Days, $upTime.Hours, $upTime.Minutes, $upTime.Seconds) -ForegroundColor $textColor

Write-Host ""
Write-Host $titleIndex "Minecraft start time" -ForegroundColor $subtColor
$mcFound = $false
$hsperfdataPath = Resolve-Path -path "$env:TEMP\hsperfdata*"
$javaPIDs = Get-ChildItem -Path $hsperfdataPath -Recurse -Force -File
foreach ($java in $javaPIDs) {
  $procPid = $java.Name
  $process = Get-Process -Id $procPid
  $modules = $process.Modules.FileVersionInfo.InternalName

  if ($modules -contains "jvm") {
    $mcFound = $true
    $startTime = $process.StartTime
    $upTime = $currentDate - $startTime
    $mName = $process.Name
  }
  Write-Host $titleIndex " Minecraft process found: $mName ($procPid) " -ForegroundColor $textColor -NoNewline
  Write-Host ("{0}d {1}h {2}m {3}s" -f $upTime.Days, $upTime.Hours, $upTime.Minutes, $upTime.Seconds) -ForegroundColor Green
}
if (-not $mcFound) {
  Write-Host $titleIndex " No Minecraft processes found..." -ForegroundColor $textColor 
}

Write-Host ""
Write-Host $titleIndex "Connected drives" -ForegroundColor $subtColor
$drives = Get-Drives
if ($drives) {
  foreach ($drive in $drives) {
    Write-Host $titleIndex (" {0,-2} {1,-5} {2}" -f $drive.DriveLetter, $drive.FileSystem, $drive.DevicePath) -ForegroundColor $textColor
  }
}

Write-Host "`nSERVICE STATUS" -ForegroundColor $titleColor

$services = ("SysMain", "PcaSvc", "DPS", "EventLog", "Schedule", "Diagtrack", "Dusmsvc", "Appinfo", "DcomLaunch", "wsearch", "BAM")
$serviceInfo = [Collections.Generic.List[object]]::new()
$allServices = Get-CimInstance Win32_Service

foreach ($service in $services) {
  $info = $allServices | Where-Object { $_.Name -eq $service }

  if ($info) {
    $sName = $info.Name
    $state = $info.State
    $procPid = $info.ProcessId

    $process = Get-Process -Id $procPid
    $startTime = $process.StartTime
  }
  else {
    $info = Get-Service -Name $service
    $sName = $info.Name
    $state = $info.Status
    $procPid = $null
    $startTime = $null
  }
    
  $serviceInfo.Add([pscustomobject]@{
      Name  = $sName
      State = $state
      Start = $startTime
      PID   = $procPid
    }
  )
}

foreach ($service in $serviceInfo) {
  $statusColor = if ($service.State -eq "Running") { "Green" } else { "Red" }
  $startTime = if ($service.Start) { $service.Start.ToString($formatDate) } else { "Unknown" }

  Write-Host $titleIndex ("{0,-11}" -f $service.Name) -ForegroundColor $textColor -NoNewline
  Write-Host "$($service.State)`t" -ForegroundColor $statusColor -NoNewline
  Write-Host $startTime -ForegroundColor $subtColor
}

Write-Host "`nSUSPICIOUS EVENT LOGS" -ForegroundColor $titleColor
$winevt = "SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels"
$eventLog = "SYSTEM\CurrentControlSet\Services\EventLog"
$events = @(
  @{Message   = "USN Journal Cleared"
    Log       = "(Application 3079)"
    Registry  = "$winevt\Microsoft-Windows-Ntfs/Operational"
    LastEvent = Get-Winevent -LogName "Application" -FilterXPath "*[System[EventID=3079]]" -MaxEvents 1
  }
  @{Message   = "Event Logs Cleared"
    Log       = "(System 104)"
    Registry  = "$eventLog\Application"
    LastEvent = Get-Winevent -LogName "System" -FilterXPath "*[System[EventID=104]]" -MaxEvents 1
  }
  @{Message   = "Security Log Cleared"
    Log       = "(Security 1102)"
    Registry  = "$eventLog\Security"
    LastEvent = Get-Winevent -LogName "Security" -FilterXPath "*[System[EventID=1102]]" -MaxEvents 1
  }
  @{Message   = "EventLog Started"
    Log       = "(System 6005)"
    Registry  = "$eventLog\System"
    LastEvent = Get-Winevent -LogName "System" -FilterXPath "*[System[EventID=6005]]" -MaxEvents 1
  }
  @{Message   = "System time changed"
    Log       = "(Security 4616)"
    Registry  = "$eventLog\Security"
    LastEvent = Get-Winevent -LogName "Security" -FilterXPath "*[System[EventID=4616]]" -MaxEvents 1
  }
)

$counter = 0

foreach ($event in $events) {
  $lastEvent = if ($event.LastEvent) { $event.LastEvent.TimeCreated.ToString($formatDate) } else { "No records found" }
  $color = if ($lastEvent -eq "No records found") { "Yellow" } else { "Green" }
  $lwt = [RegUtil]::GetLastWriteTime($event.Registry).ToString($formatDate)

  Write-Host $titleIndex ("{0,-20}: " -f $event.Message) -ForegroundColor $textColor -NoNewline
  Write-Host ("{0,-20} " -f $lastEvent) -ForegroundColor $color -NoNewline
  Write-Host $event.Log -ForegroundColor $subtColor

  Write-Host $titleIndex " Last modified: $lwt`n"
}

Write-Host "`nCOMMON FILES" -ForegroundColor $titleColor

$recyclePath = "$env:SystemDrive\`$Recycle.bin"
Write-Host $titleIndex "Recycle Bin" -ForegroundColor $subtColor

if (Test-Path $recyclePath) {
  $file = Get-Item -LiteralPath $recyclePath -Force
  $lastModified = $file.LastWriteTime

  $totalItems = 0
  $lastItem = $null

  Get-ChildItem -LiteralPath $recyclePath -Force | ForEach-Object {
    if ($_.LastWriteTime -ge $lastModified) { $lastModified = $_.LastWriteTime }
      
    Get-ChildItem -LiteralPath $_.FullName -Force | 
    ForEach-Object {
      $totalItems++
      if (-not $lastItem) { $lastItem = $_ }
      elseif ($_.LastWriteTime -ge $lastItem.LastWriteTime) { $lastItem = $_ }
    }
  }

  Write-Host $inforIndex "Total Items:       " -ForegroundColor $textColor -NoNewline
  Write-Host $totalItems -ForegroundColor $subtColor
    
  Write-Host $inforIndex "Last Deleted Item: " -ForegroundColor $textColor -NoNewline

  if ($lastItem) { 
    Write-Host $lastItem.Name -ForegroundColor $subtColor 
  }
  else { 
    Write-Host "No items found" -ForegroundColor $subtColor 
  }

  Write-Host $inforIndex "Modified Time:     " -ForegroundColor $textColor -NoNewline
  Write-Host $lastModified -ForegroundColor $subtColor
}
else {
  Write-Host $inforIndex "$recyclePath not found." -ForegroundColor Red
}

Write-Host ""
Write-Host $titleIndex "Console Host History" -ForegroundColor $subtColor
$consoleHistPath = (Get-PSReadLineOption).HistorySavePath

if (Test-Path $consoleHistPath) {
  $file = Get-Item -LiteralPath $consoleHistPath -Force
  $lastLine = Get-Content -LiteralPath $consoleHistPath -Last 1

  $attributes = $file.Attributes
  $lastModified = $file.LastWriteTime
  
  $status = if ($attributes -ne [IO.FileAttributes]::Archive) { $attributes } else { "Normal" }
  $color = if ($status -eq "Normal") { "Green" } else { "Red" }
  $lastCommand = if ($lastLine -eq "}") { "ScriptBlock" } else { $lastLine }

  Write-Host $inforIndex "Last Command:    " -ForegroundColor $textColor -NoNewline
  Write-Host $lastCommand -ForegroundColor $subtColor

  Write-Host $inforIndex "File Attributes: " -ForegroundColor $textColor -NoNewline
  Write-Host $status -ForegroundColor $color

  Write-Host $inforIndex "Modified Time:   " -ForegroundColor $textColor -NoNewline
  Write-Host $lastModified -ForegroundColor $subtColor
}
else {
  Write-Host $inforIndex "$consoleHistPath not found." -ForegroundColor Red
}

Write-Host ""
Write-Host $titleIndex "Hosts" -ForegroundColor $subtColor
$hostsPath = "$env:SystemRoot\System32\Drivers\etc\hosts"

if (Test-Path $hostsPath) {
  $file = Get-Item -LiteralPath $hostsPath

  $attributes = $file.Attributes
  $aColor = if ($attributes -eq [IO.FileAttributes]::Archive) { "Green" } else { "Red" }

  $lastModified = $file.LastWriteTime
  $content = Get-Content -LiteralPath $file.FullName

  $sLines = 0

  Write-Host $inforIndex "File Attributes:  " -ForegroundColor $textColor -NoNewline
  Write-Host $attributes -ForegroundColor $aColor
  
  Write-Host $inforIndex "Modified Time:    " -ForegroundColor $textColor -NoNewline
  Write-Host $lastModified -ForegroundColor $subtColor

  Write-Host $inforIndex "Suspicious Lines: " -ForegroundColor $textColor -NoNewline
  foreach ($line in $content) {
    if ($line.StartsWith("#")) { continue }
    elseif ([string]::IsNullOrEmpty($line)) { continue }
    
    if ($sLines -eq 0) { 
      Write-Host "Suspicious lines found" -ForegroundColor Red
    }

    $sLines++

    if ($sLines -le 3) { 
      Write-Host $inforIndex " |- " -ForegroundColor $subtColor -NoNewline
      Write-Host $line -ForegroundColor Red
    }
  }

  if ($sLines) {
    $otherLines = ($sLines - 3)
    if ($otherLines -gt 0) {
      Write-Host $inforIndex " |- And" -ForegroundColor $subtColor -NoNewline
      Write-Host " $otherLines " -ForegroundColor Red -NoNewline
      Write-Host "more..." -ForegroundColor $subtColor
    }
  }
  else { 
    Write-Host "No suspicious lines found" -ForegroundColor Green
  }
}
else {
  Write-Host $inforIndex "Hosts not found in '$hostsPath'" -ForegroundColor Red
}

Write-Host ""
Write-Host $titleIndex 'USNJournal ($UsnJrnl:$J)'

try {
  $checkDJUri = "https://github.com/Orbdiff/CheckDeletedUSN/releases/download/v0.2.1/CheckDeletedUSN.exe"
  $checkDJ = "$env:TEMP\CheckDeletedUSN.exe"
  Invoke-WebRequest -Uri $checkDJUri -UseBasicParsing -OutFile $checkDJ -ErrorAction Stop
  $journalInfo = "" | & $checkDJ

  $jrnlPath = $journalInfo[1].Substring($journalInfo[1].IndexOf(":\") - 1)
  [datetime]$jrnlCreation = $journalInfo[2].Substring(31)
  $jrnlState = $journalInfo[5].Substring(4) 
  $sColor = if ($jrnlState -eq '$UsnJrnl:$J Intact!') { "Green" } else { "Red" }

  Write-Host $inforIndex "File Path: " -ForegroundColor $textColor -NoNewline
  Write-Host $jrnlPath

  Write-Host $inforIndex "Created:   " -ForegroundColor $textColor -NoNewline
  Write-Host $jrnlCreation

  Write-Host $inforIndex "State:     " -ForegroundColor $textColor -NoNewline
  Write-Host $jrnlState -ForegroundColor $sColor
}
catch {
  Write-Host $inforIndex "Error downloading: $checkDJUri" -ForegroundColor Red
}

Write-Host ""
Write-Host $titleIndex "TEMP" -ForegroundColor $subtColor
$tmp = $env:TEMP

if (Test-Path $tmp) {
  $jnativeHook = Get-ChildItem -LiteralPath $tmp -Filter "JNativeHook*" -Force
  $javaLauncher = Get-Item -LiteralPath "$tmp\JavaLauncher.log" -Force
  
  Write-Host $inforIndex "Javalauncher: " -ForegroundColor $textColor -NoNewline
  if ($javaLauncher) {
    $content = Get-Content -LiteralPath $javaLauncher.FullName
    $javaExecutions = @{}
    $color = "Green"

    foreach ($line in $content) {
      $line = $line.ToLower()
      if ($line.StartsWith("[") -and $line.EndsWith("]")) { 
        $splitLine = $line.Split("[,")
        $date = [DateTime]($splitLine[1])
      }
      
      elseif ($line.Contains("-jar")) {
        $splitLine = $line.Split("),")
        $jar = $splitLine[1]
      } 
      
      else { continue }

      if ($date -and $jar) {
        if ($javaExecutions[$jar]) { $javaExecutions[$jar] = $date }
        else { $javaExecutions.Add($jar, $date) }

        $jar = $null
        $date = $null
      }
      
      $color = "Yellow"
    }

    Write-Host "JavaLauncher.log found" -ForegroundColor $subtColor
    
    $attributes = $javaLauncher.Attributes
    $aColor = if ($attributes -eq [IO.FileAttributes]::Archive) { "Green" } else { "Red" }

    Write-Host $inforIndex "`tFile Attributes: " -ForegroundColor $textColor -NoNewline
    Write-Host $attributes -ForegroundColor $aColor

    $executions = $javaExecutions.GetEnumerator().Count -ge 1
    Write-Host "`tExecution(s) found:" -ForegroundColor $textColor

    if ($executions) {
      $counter = 0
      $javaExecutions.GetEnumerator() | ForEach-Object {
        $counter++
        $eTime = $_.Value.ToString($formatDate)
        
        Write-Host "`t$counter. $($eTime): " -ForegroundColor $subtColor -NoNewline
        Write-Host $_.Key -ForegroundColor $color
      }
    }
    else {
      Write-Host "No entries found" -ForegroundColor Green
    }
  }
  else {
    Write-Host "JavaLauncher.log not found" -ForegroundColor Green 
  }

  Write-Host ""
  Write-Host $inforIndex "JNativeHook:  " -ForegroundColor $textColor -NoNewline

  if ($jnativeHook) {
    Write-Host "JnativeHook files found" -ForegroundColor $subtColor
    
    $counter = 0
    $jnativeHook | ForEach-Object {
      $counter++
      $lwt = $_.LastWriteTime.ToString($formatDate)
      Write-Host $inforIndex "`t$counter. $($lwt): " -ForegroundColor $subtColor -NoNewline
      Write-Host $_.FullName -ForegroundColor Yellow
    }
  }
  else { 
    Write-Host "No JNativeHook files found" -ForegroundColor Green 
  }
}
else {
  Write-Host $inforIndex "$tmp not found??" -ForegroundColor Red
}

Write-Host "`nPREFETCH INTEGRITY" -ForegroundColor $titleColor

$prefetchPath = "$env:SystemRoot\Prefetch"

Write-Host $titleIndex "Prefetch status: " -ForegroundColor $textColor -NoNewline
Write-Host "Scanning..." -ForegroundColor $subtColor -NoNewline

Write-Host ("`r{0,1}" -f "") "Prefetch status: " -ForegroundColor $textColor -NoNewline

if (Test-Path $prefetchPath) {
  $files = Get-ChildItem -LiteralPath $prefetchPath -Filter *.pf -Force

  $suspiciousFiles = 0
  $hashTable = @{}

  foreach ($file in $files) {
    $fileName = $file.Name
    $sha256 = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    $hash = if ($sha256) { $sha256 } else { "Unknown" }
    $isHidden = $file.Attributes -band [IO.FileAttributes]::Hidden

    if ($hashTable.ContainsKey($hash)) { 
      $hashTable[$hash].Add($fileName)
      
      if ($suspiciousFiles -eq 0) { Write-Host "Suspicious `n" -ForegroundColor Yellow }
      $suspiciousFiles++

      continue
    }
    else {
      $hashTable[$hash] = [Collections.Generic.List[string]]::new()
      $hashTable[$hash].Add($fileName)
    }

    if ($file.IsReadOnly -and $isHidden) { 
      if ($suspiciousFiles -eq 0) { Write-Host "Suspicious `n" -ForegroundColor Yellow }
      Write-Int $inforIndex "-" "Read-Only and Hidden file"

      Write-Host $inforIndex " |- File: " -ForegroundColor $subtColor -NoNewline
      Write-Host $fileName -ForegroundColor Red 
      Write-Host ""

      $suspiciousFiles++
    }

    elseif ($file.IsReadOnly) {
      if ($suspiciousFiles -eq 0) { Write-Host "Suspicious `n" -ForegroundColor Yellow }
      Write-Int $inforIndex "-" "Read-Only file"

      Write-Host $inforIndex " |- File: " -ForegroundColor $subtColor -NoNewline
      Write-Host $fileName -ForegroundColor Red
      Write-Host ""

      $suspiciousFiles++
    }

    elseif ($isHidden) {
      if ($suspiciousFiles -eq 0) { Write-Host "Suspicious `n" -ForegroundColor Yellow }
      Write-Int $inforIndex "-" "Hidden file"

      Write-Host $inforIndex " |- File: " -ForegroundColor $subtColor -NoNewline
      Write-Host $fileName -ForegroundColor Red
      Write-Host ""

      $suspiciousFiles++
    }

    else {
      $b = New-Object char[] 3
      
      try {
        $reader = [IO.StreamReader]::new($file.FullName)
        $null = $reader.ReadBlock($b, 0, 3)
        $reader.Close()
      }
      catch {}

      $mam = -join $b
      
      if ($mam -ne "MAM") {
        if ($suspiciousFiles -eq 0) { Write-Host "Suspicious `n" -ForegroundColor Yellow }
        Write-Int $inforIndex "-" "Does not contain 'MAM'"

        Write-Host $inforIndex " |- File: " -ForegroundColor $subtColor -NoNewline
        Write-Host $fileName -ForegroundColor Red
        Write-Host ""

        $suspiciousFiles++
      }
    }
  }

  $duplicatedHash = $hashTable.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } 
  if ($duplicatedHash) {
    $duplicatedHash | ForEach-Object {

      Write-Int $inforIndex "-" "Duplicated Hash"

      Write-Host $inforIndex " |- Files: " -ForegroundColor $subtColor -NoNewline
      $counter = $_.Value.Count

      foreach ($file in $_.Value) {
        $counter--
        $comma = if ($counter -eq 0) { "" } else { "," }

        Write-Host $file -ForegroundColor Red -NoNewline
        Write-Host ("{0} " -f $comma) -ForegroundColor $subtColor -NoNewline
      }

      Write-Host ""
      Write-Host $inforIndex " |- Hash:  $($_.Key)" -ForegroundColor $subtColor
    }
  }

  if ($suspiciousFiles -eq 0) {
    Write-Host "Prefetch folder is clean" -ForegroundColor Green 
  }
} 
else { 
  Write-Host "Prefetch folder not found in '$prefetchPath'" -ForegroundColor Red 
}

Write-Host "`nREGISTRY" -ForegroundColor $titleColor

$registryItems = @(
  @{Name     = "PowerShell Logging"
    Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    Key      = "EnableScriptBlockLogging"
    Disabled = 0
  },
  @{Name     = "Activities Cache"
    Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    Key      = "EnableActivityFeed"
    Disabled = 0
  },
  @{Name     = "Prefetch Enabled"
    Path     = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    Key      = "EnablePrefetcher"
    Disabled = 0
  },
  @{Name     = "PCA Client Enabled"
    Path     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"
    Key      = "DisabledPCA"
    Disabled = 1
  },
  @{Name     = "Command Prompt"
    Path     = "HKCU:\Software\Policies\Microsoft\Windows\System"
    Key      = "DisableCMD"
    Disabled = 1
  }
)

foreach ($item in $registryItems) {
  $itemProperty = Get-ItemProperty -LiteralPath $item.Path -Name $item.Key
  $color = "Green"
  $lwt = $null
  
  if ($item.Path.StartsWith("HKLM:\")) {
    $rPath = $item.Path.TrimStart("HKLM:\")
    $lwt = [RegUtil]::GetLastWriteTime($rPath).ToString($formatDate)
    $lwt = if ($lwt -eq "31-12-1600 21:00:00") { "(Never Modified)" } else { "($lwt)" }
  }

  if ($itemProperty.$($item.Key) -eq $item.Disabled) { 
    $status = "Disabled"
    $color = "Red"  
  } 
  else { 
    $status = if ($item.Name -ne "Command Prompt") { "Enabled" } else { "Available" }
  }

  Write-Host $inforIndex "$($item.Name):`t" -ForegroundColor $textColor -NoNewline
  Write-Host $status -ForegroundColor $color -NoNewline
  Write-Host "`t  $lwt"
}

Write-Host $inforIndex "Debuggers (IFEO):`t" -ForegroundColor $textColor -NoNewline
try {
  $counter = 1
  $currentVersion = Get-ChildItem -LiteralPath "HKLM:\Software\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
}
catch [Security.SecurityException] {
  Write-Host "Denied access to: $($_.TargetObject)! " -ForegroundColor Yellow -NoNewline
}
catch {
  Write-Host "$($_.Exception): $($_.TargetObject)!" -ForegroundColor Yellow -NoNewline
}
finally {
  $currentVersion = Get-ChildItem -LiteralPath "HKLM:\Software\Microsoft\Windows NT\CurrentVersion"
  foreach ($folder in $currentVersion) {
    try {
      $items = Get-ChildItem -LiteralPath $folder.PSPath -ErrorAction Stop
    }
    catch [Security.SecurityException] {
      $exception = "Denied access"
      $target = $_.TargetObject
    }
    catch {
      $exception = $_.Exception
      $target = $_.TargetObject
    }
    finally {
      $items = Get-ChildItem -LiteralPath $folder.PSPath
    }
  
    $items | ForEach-Object {
      $debugger = (Get-ItemProperty $_.PSPath).Debugger
      
      if ($debugger) {
  
        if ($counter -eq 1) {
          Write-Host "Debuggers found`n" -ForegroundColor Red
        }
  
        Write-Int $inforIndex $counter "Debugger found"
        
        Write-Host $inforIndex " |- Registry Path: " -ForegroundColor $subtColor -NoNewline
        Write-Host $_.Name -ForegroundColor Yellow
  
        Write-Host $inforIndex " |- Executable:    " -ForegroundColor $subtColor -NoNewline
        Write-Host $_.PSChildName -ForegroundColor Yellow
  
        Write-Host $inforIndex " |- Debugger:      " -ForegroundColor $subtColor -NoNewline
        Write-Host $debugger -ForegroundColor Yellow
  
        Write-Host ""
  
        $counter++
      }
    }
  }
  if ($counter -eq 1) {
    Write-Host "Not found" -ForegroundColor Green
  } 
  
  if ($exception) {
    Write-Int $inforIndex "-" "Problem found"
    Write-Host $inforIndex " |- $exception : " -ForegroundColor $subtColor -NoNewline
    Write-Host $target -ForegroundColor Yellow
  }
}
