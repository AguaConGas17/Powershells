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
  # ty diff x2 xd
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
function Get-ServiceInfo([string[]]$services) {
  $list = [Collections.Generic.List[object]]::new()
  $allServices = Get-CimInstance Win32_Service

  foreach ($service in $services) {
    if ($service -eq "BAM") {
      $info = Get-Service -Name $service -ErrorAction Continue
      $name = $info.Name
      $state = $info.Status
      $sPid = $null
      $startTime = $null
    }
    else {
      $info = $allServices | Where-Object { $_.Name -eq $service }
      $name = $info.Name
      $state = $info.State
      $sPid = $info.ProcessId

      $process = Get-Process -Id $sPid -ErrorAction SilentlyContinue
      $startTime = $process.StartTime
    }
    
    $list.Add([pscustomobject]@{
        Name  = $name
        State = $state
        Start = $startTime
        PID   = $sPid
      })
  }
  return $list
}
function Write-Int($indx, $simb, $message) {
  Write-Host $indx "[" -ForegroundColor Gray -NoNewline
  Write-Host $simb -ForegroundColor Yellow -NoNewline
  Write-Host "] " -ForegroundColor Gray -NoNewline
  
  Write-Host $message -ForegroundColor Yellow
}

$titleIndex = ("{0,1}" -f "")
$inforIndex = ("{0,2}" -f "")
$titleColor = "DarkMagenta"
$formatDate = "dd-MM-yyyy HH:mm:ss"
$currentDate = Get-Date

Write-Host "Script by " -NoNewline
Write-Host "aguacongas17 :)`n" -ForegroundColor Red

Write-Host "GENERAL INFORMATION`n" -ForegroundColor $titleColor

Write-Host $titleIndex "System boot time" -ForegroundColor Gray

$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$upTime = $currentDate - $bootTime
Write-Host $titleIndex " Last Boot:" -ForegroundColor White -NoNewline
Write-Host " $bootTime " -ForegroundColor Green -NoNewline
Write-Host ("({0}d {1}h {2}m {3}s)" -f $upTime.Days, $upTime.Hours, $upTime.Minutes, $upTime.Seconds) -ForegroundColor White

Write-Host ""
Write-Host $titleIndex "Minecraft start time" -ForegroundColor Gray
$javaProcesses = Get-Process -Name "java*" -ErrorAction SilentlyContinue
if ($javaProcesses) {
  $javaProcesses | ForEach-Object {
    $st = $_.StartTime
    $upTime = $currentDate - $st
    $pPid = $_.Id
    $name = $_.Name

    Write-Host $titleIndex " $name ($pPid):" -ForegroundColor White -NoNewline
    Write-Host " $st " -ForegroundColor Green -NoNewline
    Write-Host ("({0}d {1}h {2}m {3}s)" -f $upTime.Days, $upTime.Hours, $upTime.Minutes, $upTime.Seconds) -ForegroundColor White
  }
}
else { Write-Host $titleIndex " No Minecraft processes found..." -ForegroundColor White }

Write-Host ""
Write-Host $titleIndex "Connected drives" -ForegroundColor Gray
$drives = Get-Drives
if ($drives) {
  foreach ($drive in $drives) {
    Write-Host $titleIndex (" {0,-2} {1,-5} {2}" -f $drive.DriveLetter, $drive.FileSystem, $drive.DevicePath) -ForegroundColor White
  }
}

Write-Host "`nSERVICE STATUS`n" -ForegroundColor $titleColor

$services = ("SysMain", "PcaSvc", "DPS", "EventLog", "Schedule", "Diagtrack", "Dusmsvc", "Appinfo", "DcomLaunch", "wsearch", "BAM")
$serviceInfo = Get-ServiceInfo -Services $services

foreach ($service in $serviceInfo) {
  $statusColor = if ($service.State -eq "Running") { "Green" } else { "Red" }
  $startTime = if ($service.Start) { $service.Start.ToString($formatDate) } else { "Unknown" }

  Write-Host $titleIndex ("{0,-11}" -f $service.Name) -ForegroundColor White -NoNewline
  Write-Host ("{0}`t" -f $service.State) -ForegroundColor $statusColor -NoNewline
  Write-Host $startTime -ForegroundColor Gray
}

Write-Host "`nSUSPICIOUS EVENT LOGS`n" -ForegroundColor $titleColor
$winevt = "SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels"
$eventLog = "SYSTEM\CurrentControlSet\Services\EventLog"
$events = @(
  @{Message   = "USN Journal Cleared"
    Log       = "(Application 3079)"
    Registry  = "$winevt\Microsoft-Windows-Ntfs/Operational"
    LastEvent = Get-Winevent -LogName "Application" -FilterXPath "*[System[EventID=3079]]" -MaxEvents 1 -ErrorAction SilentlyContinue
  }
  @{Message   = "USN Journal Cleared"
    Log       = "(Ntfs\Opera. 501)"
    Registry  = "$winevt\Microsoft-Windows-Ntfs/Operational"
    LastEvent = Get-Winevent -LogName "microsoft-windows-ntfs/operational" -FilterXPath "*[System[EventID=501]]" -ErrorAction SilentlyContinue | 
    Where-Object { $_.message.Contains("fsutil") } | Select-Object -First 1
  }
  @{Message   = "Event Logs Cleared"
    Log       = "(System 104)"
    Registry  = "$eventLog\Application"
    LastEvent = Get-Winevent -LogName "System" -FilterXPath "*[System[EventID=104]]" -MaxEvents 1 -ErrorAction SilentlyContinue
  }
  @{Message   = "Security Log Cleared"
    Log       = "(Security 1102)"
    Registry  = "$eventLog\Security"
    LastEvent = Get-Winevent -LogName "Security" -FilterXPath "*[System[EventID=1102]]" -MaxEvents 1 -ErrorAction SilentlyContinue
  }
  @{Message   = "EventLog Started"
    Log       = "(System 6005)"
    Registry  = "$eventLog\System"
    LastEvent = Get-Winevent -LogName "System" -FilterXPath "*[System[EventID=6005]]" -MaxEvents 1 -ErrorAction SilentlyContinue
  }
  @{Message   = "System time changed"
    Log       = "(Security 4616)"
    Registry  = "$eventLog\Security"
    LastEvent = Get-Winevent -LogName "Security" -FilterXPath "*[System[EventID=4616]]" -MaxEvents 1 -ErrorAction SilentlyContinue
  }
)

$counter = 0

foreach ($event in $events) {
  $lastEvent = if ($event.LastEvent) { $event.LastEvent.TimeCreated.ToString($formatDate) } else { "No records found" }
  $color = if ($lastEvent -eq "No records found") { "Yellow" } else { "Green" }
  $lwt = [RegUtil]::GetLastWriteTime($event.Registry)

  Write-Host $titleIndex ("{0,-20}: " -f $event.Message) -ForegroundColor White -NoNewline
  Write-Host ("{0,-20} " -f $lastEvent) -ForegroundColor $color -NoNewline
  Write-Host $event.Log -ForegroundColor Gray

  Write-Host $titleIndex " |- Last modified: $lwt`n"
}

Write-Host "`nCOMMON FILES`n" -ForegroundColor $titleColor

$recyclePath = [string]($env:SystemDrive + '\$Recycle.bin')
Write-Host $titleIndex "Recycle Bin" -ForegroundColor Gray

if (Test-Path $recyclePath) {
  $file = Get-Item -LiteralPath $recyclePath -Force
  $lastModified = $file.LastWriteTime

  $totalItems = 0
  $lastItem = $null

  Get-ChildItem -LiteralPath $recyclePath -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.LastWriteTime -ge $lastModified) { $lastModified = $_.LastWriteTime }
      
    Get-ChildItem -LiteralPath $_.FullName -Force | 
    ForEach-Object {
      $totalItems++
      if (-not $lastItem) { $lastItem = $_ }
      elseif ($_.LastWriteTime -ge $lastItem.LastWriteTime) { $lastItem = $_ }
    }
  }

  Write-Host $inforIndex "Total Items: `t" -ForegroundColor White -NoNewline
  Write-Host $totalItems -ForegroundColor Gray
    
  Write-Host $inforIndex "Last Deleted Item:`t" -ForegroundColor White -NoNewline

  if ($lastItem) { 
    Write-Host $lastItem.Name -ForegroundColor Gray 
  }
  else { 
    Write-Host "No items found" -ForegroundColor Gray 
  }

  Write-Host $inforIndex "Modified Time:`t" -ForegroundColor White -NoNewline
  Write-Host $lastModified -ForegroundColor Gray
}
else {
  Write-Host $inforIndex "$recyclePath not found." -ForegroundColor Red
}

Write-Host ""
Write-Host $titleIndex "Console Host History" -ForegroundColor Gray
$consoleHistPath = (Get-PSReadLineOption).HistorySavePath

if (Test-Path $consoleHistPath) {
  $file = Get-Item -LiteralPath $consoleHistPath -Force -ErrorAction SilentlyContinue
  $lastLine = Get-Content -LiteralPath $consoleHistPath -Last 1

  $attributes = $file.Attributes
  $lastModified = $file.LastWriteTime
  
  $status = if ($attributes -ne [IO.FileAttributes]::Archive) { $attributes } else { "Normal" }
  $color = if ($status -eq "Normal") { "Green" } else { "Red" }
  $lastCommand = if ($lastLine -eq "}") { "ScriptBlock" } else { $lastLine }

  Write-Host $inforIndex "Last Command:`t" -ForegroundColor White -NoNewline
  Write-Host $lastCommand -ForegroundColor Gray

  Write-Host $inforIndex "File Attributes:`t" -ForegroundColor White -NoNewline
  Write-Host $status -ForegroundColor $color

  Write-Host $inforIndex "Modified Time:`t" -ForegroundColor White -NoNewline
  Write-Host $lastModified -ForegroundColor Gray
}
else {
  Write-Host $inforIndex "$consoleHistPath not found." -ForegroundColor Red
}

Write-Host ""
Write-Host $titleIndex "Hosts" -ForegroundColor Gray
$hostsPath = "$env:SystemRoot\System32\Drivers\etc\hosts"

if (Test-Path $hostsPath) {
  $file = Get-Item -LiteralPath $hostsPath

  $attributes = $file.Attributes
  $aColor = if ($attributes -eq [IO.FileAttributes]::Archive) { "Green" } else { "Red" }

  $lastModified = $file.LastWriteTime
  $content = Get-Content -LiteralPath $file.FullName

  $sLines = 0

  Write-Host $inforIndex "File Attributes:`t" -ForegroundColor White -NoNewline
  Write-Host $attributes -ForegroundColor $aColor
  
  Write-Host $inforIndex "Modified Time:`t" -ForegroundColor White -NoNewline
  Write-Host $lastModified -ForegroundColor Gray

  Write-Host $inforIndex "Suspicious Lines:`t" -ForegroundColor White -NoNewline
  foreach ($line in $content) {
    if ($line.StartsWith("#")) { continue }
    elseif ([string]::IsNullOrEmpty($line)) { continue }
    
    if ($sLines -eq 0) { 
      Write-Host "Suspicious lines found" -ForegroundColor Red
    }

    $sLines++

    if ($sLines -le 3) { 
      Write-Host $inforIndex " |- " -ForegroundColor Gray -NoNewline
      Write-Host $line -ForegroundColor Red
    }
  }

  if ($sLines) {
    $otherLines = ($sLines - 3)
    if ($otherLines -gt 0) {
      Write-Host $inforIndex " |- And" -ForegroundColor Gray -NoNewline
      Write-Host " $otherLines " -ForegroundColor Red -NoNewline
      Write-Host "more..." -ForegroundColor Gray
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
Write-Host $titleIndex "TEMP" -ForegroundColor Gray
$tmp = $env:TEMP

if (Test-Path $tmp) {
  $jnativeHook = Get-ChildItem -LiteralPath $tmp -Filter "JNativeHook*" -Force -ErrorAction SilentlyContinue
  $javaLauncher = Get-Item -LiteralPath "$tmp\JavaLauncher.log" -Force -ErrorAction SilentlyContinue
  
  Write-Host $inforIndex "Javalauncher: " -ForegroundColor White -NoNewline
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

    Write-Host "JavaLauncher.log found" -ForegroundColor Gray
    
    $attributes = $javaLauncher.Attributes
    $aColor = if ($attributes -eq [IO.FileAttributes]::Archive) { "Green" } else { "Red" }

    Write-Host $inforIndex "`tFile Attributes: " -ForegroundColor White -NoNewline
    Write-Host $attributes -ForegroundColor $aColor

    $executions = $javaExecutions.GetEnumerator().Count -ge 1

    if ($executions) {
      Write-Host "`tExecution(s) found:" -ForegroundColor White
      $javaExecutions.GetEnumerator() | ForEach-Object {
        Write-Host ("`t - {0}: " -f $_.Value) -ForegroundColor Gray -NoNewline
        Write-Host $_.Key -ForegroundColor $color
      }
    }
    else {
      Write-Host $inforIndex "`tEntries: " -ForegroundColor White -NoNewline
      Write-Host "No entries found" -ForegroundColor Green
    }
  }
  else {
    Write-Host "JavaLauncher.log not found" -ForegroundColor Green 
  }

  Write-Host ""
  Write-Host $inforIndex "JNativeHook:  " -ForegroundColor White -NoNewline

  if ($jnativeHook) {
    Write-Host "JnativeHook files found" -ForegroundColor Gray
    
    $jnativeHook | ForEach-Object {
      Write-Host ("`t{0} {1}: " -f "-", $_.LastWriteTime) -ForegroundColor Gray -NoNewline
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

Write-Host "`nPREFETCH INTEGRITY`n" -ForegroundColor $titleColor

$prefetchPath = "$env:SystemRoot\Prefetch"

Write-Host $titleIndex "Prefetch status: " -ForegroundColor Gray -NoNewline
Write-Host "Scanning..." -ForegroundColor Gray -NoNewline

Write-Host ("`r{0,1}" -f "") "Prefetch status: " -ForegroundColor Gray -NoNewline

if (Test-Path $prefetchPath) {
  $files = Get-ChildItem -LiteralPath $prefetchPath -Filter *.pf -Force

  $suspiciousFiles = 0
  $hashTable = @{}

  foreach ($file in $files) {
    $fileName = $file.Name
    $sha256 = (Get-FileHash -Path $file.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
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

      Write-Host $inforIndex " |- File: " -ForegroundColor Gray -NoNewline
      Write-Host $fileName -ForegroundColor Red 
      Write-Host ""

      $suspiciousFiles++
    }

    elseif ($file.IsReadOnly) {
      if ($suspiciousFiles -eq 0) { Write-Host "Suspicious `n" -ForegroundColor Yellow }
      Write-Int $inforIndex "-" "Read-Only file"

      Write-Host $inforIndex " |- File: " -ForegroundColor Gray -NoNewline
      Write-Host $fileName -ForegroundColor Red
      Write-Host ""

      $suspiciousFiles++
    }

    elseif ($isHidden) {
      if ($suspiciousFiles -eq 0) { Write-Host "Suspicious `n" -ForegroundColor Yellow }
      Write-Int $inforIndex "-" "Hidden file"

      Write-Host $inforIndex " |- File: " -ForegroundColor Gray -NoNewline
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

        Write-Host $inforIndex " |- File: " -ForegroundColor Gray -NoNewline
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

      Write-Host $inforIndex " |- Files: " -ForegroundColor Gray -NoNewline
      $counter = $_.Value.Count

      foreach ($file in $_.Value) {
        $counter--
        $comma = if ($counter -eq 0) { "" } else { "," }

        Write-Host $file -ForegroundColor Red -NoNewline
        Write-Host ("{0} " -f $comma) -ForegroundColor Gray -NoNewline
      }

      Write-Host ""
      Write-Host $inforIndex (" |- Hash:  {0}" -f $_.Key) -ForegroundColor Gray
    }
  }

  if ($suspiciousFiles -eq 0) {
    Write-Host "Prefetch folder is clean" -ForegroundColor Green 
  }
} 
else { 
  Write-Host "Prefetch folder not found in '$prefetchPath'" -ForegroundColor Red 
}

Write-Host "`nREGISTRY`n" -ForegroundColor $titleColor

$registryItems = @(
  @{Name = "Command Prompt"
    Path = "HKCU:\Software\Policies\Microsoft\Windows\System"
    Key  = "DisableCMD"
  },
  @{Name = "PowerShell Logging"
    Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    Key  = "EnableScriptBlockLogging"
  },
  @{Name = "Activities Cache"
    Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    Key  = "EnableActivityFeed"
  },
  @{Name = "Prefetch Enabled"
    Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    Key  = "EnablePrefetcher"
  }
)

foreach ($item in $registryItems) {
  $itemProperty = Get-ItemProperty -LiteralPath $item.Path -Name $item.Key -ErrorAction SilentlyContinue
  $color = "Green"
  
  if ($itemProperty -and $itemProperty.$($item.Key) -eq 0) { 
    $status = "Disabled"
    $color = "Red"  
  } 
  else { 
    $status = if ($item.Name -ne "Command Prompt") { "Enabled" } else { "Available" }
  }

  Write-Host $inforIndex ("{0}:`t" -f $item.Name) -ForegroundColor White -NoNewline
  Write-Host $status -ForegroundColor $color
}

Write-Host $inforIndex "Debuggers (IFEO):`t" -ForegroundColor White -NoNewline
try {
  $counter = 1
  $currentVersion = Get-ChildItem -LiteralPath "HKLM:\Software\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
}
catch [Security.SecurityException] {
  Write-Host "Denied access to: $($_.TargetObject)! " -ForegroundColor Yellow -NoNewline
}
catch {
  Write-Host ("{0}: {1}! " -f $_.Exception, $_.TargetObject) -ForegroundColor Yellow -NoNewline
}

finally {
  $currentVersion = Get-ChildItem -LiteralPath "HKLM:\Software\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
}

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
    $items = Get-ChildItem -LiteralPath $folder.PSPath -ErrorAction SilentlyContinue
  }

  $items | ForEach-Object {
    $debugger = (Get-ItemProperty $_.PSPath).Debugger
    
    if ($debugger) {

      if ($counter -eq 1) {
        Write-Host "Debuggers found`n" -ForegroundColor Red
      }

      Write-Int $inforIndex $counter "Debugger found"
      
      Write-Host $inforIndex " |- Registry Path: " -ForegroundColor Gray -NoNewline
      Write-Host $_.Name -ForegroundColor Yellow

      Write-Host $inforIndex " |- Executable:    " -ForegroundColor Gray -NoNewline
      Write-Host $_.PSChildName -ForegroundColor Yellow

      Write-Host $inforIndex " |- Debugger:      " -ForegroundColor Gray -NoNewline
      Write-Host $debugger -ForegroundColor Yellow

      Write-Host ""

      $counter++
    }
  }
}
if ($counter -eq 1) {
  Write-Host "No Debuggers found" -ForegroundColor Green
} 

if ($exception) {
  Write-Int $inforIndex "-" "Problem found"
  Write-Host $inforIndex " |- $exception : " -ForegroundColor Gray -NoNewline
  Write-Host $target -ForegroundColor Yellow
}
