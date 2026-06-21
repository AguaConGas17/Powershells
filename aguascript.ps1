# inspirado en el script de lily looloolool http://github.com/praiselily/

Clear-Host

$IsAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
  Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor White -BackgroundColor Red -NoNewline
  Start-Sleep -Seconds 5
  exit
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Kernel32 {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern uint QueryDosDevice(string lpDeviceName, StringBuilder lpTargetPath, uint ucchMax);
}
"@

$OriginalTitle = [System.Console]::Title
[System.Console]::Title += " - SCRIPT BY AGUACONGAS17"

$TitleIndex = ("{0,1}" -f "")
$InforIndex = ("{0,2}" -f "")

Write-Host "Script by aguacongas17"

function Write-UpTime {
  param(
    [string]$Message,
    [DateTime]$Time,
    [DateTime]$From
  )

  $UpTime = $From - $Time
  $FormatDate = "dd-MM-yyyy HH:mm:ss"

  Write-Host $TitleIndex ("{0}: {1}" -f $Message, $Time.ToString($FormatDate)) -ForegroundColor White
  Write-Host $TitleIndex ("Uptime: {0} days, {1} hours and {2} minutes" -f $UpTime.Days, $UpTime.Hours, $UpTime.Minutes) -ForegroundColor White
}
function Get-Drives {
  # ty diff
  $Max = 65536
  $StringBuilder = New-Object System.Text.StringBuilder($Max)
  $driveMappings = Get-CimInstance Win32_Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
    $ReturnLength = [Kernel32]::QueryDosDevice($_.DriveLetter, $StringBuilder, $Max)
    if ($ReturnLength) {
      @{
        DriveLetter = $_.DriveLetter
        DevicePath = $StringBuilder.ToString()
        FileSystem = $_.FileSystem
      }
    }
  }
  
  return $driveMappings
}
function Get-ServiceInfo {
  param (
    [string[]]$Services
  )
  
  $List = [System.Collections.Generic.List[object]]::new()
  $AllServices = Get-CimInstance Win32_Service

  foreach ($Service in $Services) {
    if ($Service -eq "BAM") {
      $Info = Get-Service -Name $Service -ErrorAction Continue
      $Name = $Info.Name
      $State = $Info.Status
      $SPID = $null
      $StartTime = $null
    }
    else {
      $Info = $AllServices | Where-Object { $_.Name -eq $Service }
      $Name = $Info.Name
      $State = $Info.State
      $SPID = $Info.ProcessId

      $Process = Get-Process -Id $SPID
      $StartTime = $Process.StartTime
    }
    
    $List.Add([pscustomobject]@{
      Name = $Name
      State = $State
      Start = $StartTime
      PID = $SPID
    })
  }
  return $List
}

$CurrentDate = Get-Date

Write-Host "SYSTEM BOOT TIME`n" -ForegroundColor Gray

$BootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
Write-UpTime -Message "Last Boot" -Time $BootTime -From $CurrentDate

Write-Host "`nMINECRAFT START TIME`n" -ForegroundColor Gray

$JavaProcesses = Get-Process -Name "Java*" -ErrorAction SilentlyContinue
if ($JavaProcesses) {
  $JavaProcesses | ForEach-Object{
    Write-UpTime -Message $_.Name -Time $_.StartTime -From $CurrentDate
  }
} else { Write-Host $TitleIndex "No Minecraft processes found..." -ForegroundColor White }

Write-Host "`nCONNECTED DRIVES`n" -ForegroundColor Gray
$Drives = Get-Drives
if ($Drives) {
  foreach ($Drive in $Drives) {
    Write-Host $TitleIndex ("{0,-2} {1,-5} {2}" -f $Drive.DriveLetter, $Drive.FileSystem, $Drive.DevicePath) -ForegroundColor White
  }
}

$Services = ("SysMain", "PcaSvc", "DPS", "EventLog", "Schedule", "Diagtrack", "Dusmsvc", "Appinfo", "DcomLaunch", "wsearch", "BAM")
$ServiceInfo = Get-ServiceInfo -Services $Services

Write-Host "`nSERVICE STATUS`n" -ForegroundColor Gray

foreach ($Service in $ServiceInfo) {
  $StatusColor = if ($Service.State -eq "Running") { "Green" } else { "Red" }
  $StartTime = if ($Service.Start) { " $($Service.Start) " } else { " Unknown " }

  Write-Host $TitleIndex ("{0,-11}" -f $Service.Name) -ForegroundColor White -NoNewline
  Write-Host $Service.State -ForegroundColor $StatusColor -NoNewline
  Write-Host $StartTime -ForegroundColor Gray
}

Write-Host "`nSUSPICIOUS EVENT LOGS`n" -ForegroundColor Gray

$Events = @(
  @{Message = "USN Journal Cleared"
    Log = "(Application 3079)"
    LastEvent = Get-Winevent -LogName "Application" -FilterXPath "*[System[EventID=3079]]" -MaxEvents 1 -ErrorAction SilentlyContinue}
  @{Message = "USN Journal Cleared"
    Log = "(Ntfs\Opera. 501)"
    LastEvent = Get-Winevent -LogName "microsoft-windows-ntfs/operational" -FilterXPath "*[System[EventID=501]]" -MaxEvents 1 -ErrorAction SilentlyContinue}
  @{Message = "Event Logs Cleared"
    Log = "(System 104)"
    LastEvent = Get-Winevent -LogName "System" -FilterXPath "*[System[EventID=104]]" -MaxEvents 1 -ErrorAction SilentlyContinue}
  @{Message = "Security Log Cleared"
    Log = "(Security 1102)"
    LastEvent = Get-Winevent -LogName "Security" -FilterXPath "*[System[EventID=1102]]" -MaxEvents 1 -ErrorAction SilentlyContinue}
  @{Message = "EventLog Started"
    Log = "(System 6005)"
    LastEvent = Get-Winevent -LogName "System" -FilterXPath "*[System[EventID=6005]]" -MaxEvents 1 -ErrorAction SilentlyContinue}
  @{Message = "System time changed"
    Log = "(Security 4616)"
    LastEvent = Get-Winevent -LogName "Security" -FilterXPath "*[System[EventID=4616]]" -MaxEvents 1 -ErrorAction SilentlyContinue}
)

foreach ($Event in $Events) {
  $LastEvent = if ($Event.LastEvent) { $Event.LastEvent.TimeCreated } else { "No records found" }
  $Color = if ($LastEvent -eq "No records found") { "Yellow" } else { "Green" }
  
  Write-Host $TitleIndex ("{0,-20}: " -f $Event.Message) -ForegroundColor White -NoNewline
  Write-Host ("{0,-20}" -f $LastEvent) -ForegroundColor $Color -NoNewline
  Write-Host $Event.Log -ForegroundColor Gray
}

Write-Host "`nCOMMON FILES`n" -ForegroundColor Gray

$CommonFiles = @(
  @{Name = "Recycle Bin"; Path = [string]($env:SystemDrive + '\$Recycle.bin')},
  @{Name = "Console Host History"; Path = (Get-PSReadLineOption).HistorySavePath},
  @{Name = "Hosts"; Path = "$($env:SystemRoot)\System32\Drivers\etc\hosts"},
  @{Name = "TEMP"; Path = $env:TEMP}
)

foreach ($Item in $CommonFiles) {
  Write-Host $TitleIndex $Item.Name -ForegroundColor Gray

  if (-not (Test-Path $Item.Path)) {
    Write-Host $InforIndex "$($Item.Path) not found." -ForegroundColor Red
    continue
  }

  $File = Get-Item -LiteralPath $Item.Path -Force
  $LastModified = $File.LastWriteTime

  if ($Item.Name -eq "Recycle Bin") {
    $TotalItems = 0
    $LastItem = $null

    Get-ChildItem -LiteralPath $Item.Path -Force | ForEach-Object {
      if ($_.LastWriteTime -ge $LastModified) { $LastModified = $_.LastWriteTime }
      
      Get-ChildItem -LiteralPath $_.FullName -Force | 
        ForEach-Object {
          $TotalItems++
          if (-not $LastItem) { $LastItem = $_ }
          elseif ($_.LastWriteTime -ge $LastItem.LastWriteTime) { $LastItem = $_ }
      }
    }

    Write-Host $InforIndex "Total Items: `t" -ForegroundColor White -NoNewline
    Write-Host $TotalItems -ForegroundColor Gray
    
    Write-Host $InforIndex "Last Deleted Item:`t" -ForegroundColor White -NoNewline

    if ($LastItem) { Write-Host ("{0} ({1})" -f $LastItem.Name, $LastItem.LastWriteTime) -ForegroundColor Gray }
    else { Write-Host "No items found" -ForegroundColor Gray }
  }

  elseif ($Item.Name -eq "Console Host History") {
    $LastLine = Get-Content -LiteralPath $Item.Path -Last 1
    $Attributes = $File.Attributes
    
    $Status = if ($Attributes -ne [System.IO.FileAttributes]::Archive) { $Attributes } else { "Normal" }
    $Color = if ($Status -eq "Normal") { "Green" } else { "Red" }
    $LastCommand = if ($LastLine -eq "}") { "ScriptBlock" } else { $LastLine }

    Write-Host $InforIndex "Last Command:`t" -ForegroundColor White -NoNewline
    Write-Host $LastCommand -ForegroundColor Gray

    Write-Host $InforIndex "File Attributes:`t" -ForegroundColor White -NoNewline
    Write-Host $Status -ForegroundColor $Color
  }

  elseif ($Item.Name -eq "Hosts") {
    $SuspiciousLine = "None"
    $SuspiciousLines = 0
    $Content = Get-Content -LiteralPath $Item.Path 
    
    foreach ($Line in $Content) {
      if ($Line.StartsWith("#")) { continue }
      elseif ([string]::IsNullOrEmpty($Line)) { continue }

      if ($SuspiciousLine -eq "None") { $SuspiciousLine = $Line }
      $SuspiciousLines++
    }

    $Color = if ($SuspiciousLine -ne "None") { "Red" } else { "Green" }

    Write-Host $InforIndex "Suspicious Line:`t" -ForegroundColor White -NoNewline
    Write-Host $SuspiciousLine -ForegroundColor $Color

    Write-Host $InforIndex "Uncommented lines:`t" -ForegroundColor White -NoNewline
    Write-Host $SuspiciousLines -ForegroundColor $Color
  }

  elseif ($Item.Name -eq "TEMP") {
    $JnativeHook = Get-ChildItem -LiteralPath $Item.Path -Filter "JNativeHook*" -Force -ErrorAction SilentlyContinue
    $JavaLauncher = Get-Item -LiteralPath "$($Item.Path)\JavaLauncher.log" -Force -ErrorAction SilentlyContinue
    
    if ($JavaLauncher) {
      $Content = Get-Content -LiteralPath $JavaLauncher.FullName
      $JavaExecutions = @{}
      $Color = "Green"

      foreach ($Line in $Content) {
        if ($Line.StartsWith("[") -and $Line.EndsWith("]")) { 
          $SplitLine = $Line.Split("[,")
          $Date = [DateTime]($SplitLine[1])
        }
        
        elseif ($Line.Contains("-jar")) {
          $SplitLine = $Line.Split("),")
          $Jar = $SplitLine[1]
        } 
        
        else { continue }

        if ($Date -and $Jar) {
          if ($JavaExecutions[$Jar]) { $JavaExecutions[$Jar] = $Date }
          else { $JavaExecutions.Add($Jar, $Date) }

          $Jar = $null
          $Date = $null
        }
        
        $Color = "Yellow"
      }

      Write-Host $InforIndex ">> JavaLauncher.log:`t" -ForegroundColor White
      
      $Attributes = $JavaLauncher.Attributes
      if ($Attributes -ne [System.IO.FileAttributes]::Archive) { 
        Write-Host $InforIndex "`tFile Attributes: " -ForegroundColor White -NoNewline
        Write-Host $Attributes -ForegroundColor Red
      } 

      $JavaExecutions.GetEnumerator() | ForEach-Object {
        Write-Host ("`t{0} {1}:" -f "-", $_.Value) -ForegroundColor Gray -NoNewline
        Write-Host $_.Key -ForegroundColor $Color
      }
    } else { Write-Host $InforIndex ">> JavaLauncher.log not found" -ForegroundColor Green }

    if ($JnativeHook) {
      Write-Host $InforIndex ">> JnativeHook:" -ForegroundColor White
      $JnativeHook | ForEach-Object {
        Write-Host ("`t{0} {1}: " -f "-", $_.LastWriteTime) -ForegroundColor Gray -NoNewline
        Write-Host $_.FullName -ForegroundColor Yellow
      }
    } else { Write-Host $InforIndex ">> No JNativeHook files found" -ForegroundColor Green }

    continue
  }

  Write-Host $InforIndex "Modified Time:`t" -ForegroundColor White -NoNewline
  Write-Host $LastModified -ForegroundColor Gray
}

Write-Host "`nREGISTRY`n" -ForegroundColor Gray

$RegistryItems = @(
  @{Name = "Command Prompt"
    Path = "HKCU:\Software\Policies\Microsoft\Windows\System"
    Key = "DisableCMD"},
  @{Name = "PowerShell Logging"
    Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    Key = "EnableScriptBlockLogging"},
  @{Name = "Activities Cache"
    Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    Key = "EnableActivityFeed"},
  @{Name = "Prefetch Enabled"
    Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    Key = "EnablePrefetcher"},
  @{Name = "Debugger (IFEO)"
    Path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion"}
)

foreach ($Item in $RegistryItems) {
  if ($Item.Name -eq "Debugger (IFEO)") {
    $CurrentVersion = Get-ChildItem -LiteralPath $Item.Path -ErrorAction SilentlyContinue
    $Debuggers = @{}

    foreach ($Folder in $CurrentVersion) {
      Get-ChildItem -LiteralPath $Folder.PSPath | ForEach-Object {
        if ((Get-ItemProperty $_.PSPath).Debugger) { 
          $Debuggers.Add($_.PSChildName, $_.Name) 
        }
      }
    }

    if ($Debuggers.Count -ge 1) { 
      $Status = "Debuggers found"
      $Color = "Red"
    } 
    else {
      $Status = "No Debuggers found" 
      $Color = "Green" 
    }

    Write-Host $InforIndex ("{0}:`t" -f $Item.Name) -ForegroundColor White -NoNewline
    Write-Host $Status -ForegroundColor $Color

    $Debuggers.GetEnumerator() | ForEach-Object{  
      Write-Host $InforIndex ("{0,2}{1} " -f " ","-") -NoNewline
      Write-host ("{0} - {1}" -f $_.Key, $_.Value) -ForegroundColor Red
    }
    continue
  }

  $ItemProperty = Get-ItemProperty -LiteralPath $Item.Path -Name $Item.Key -ErrorAction SilentlyContinue
  $Color = "Green"
  
  if ($ItemProperty -and $ItemProperty.$($Item.Key) -eq 0) { 
    $Status = "Disabled"
    $Color = "Red"  
  } 
  else { 
    $Status = if ($Item.Name -ne "Command Prompt") { "Enabled" } else { "Available" }
  }

  Write-Host $InforIndex ("{0}:`t" -f $Item.Name) -ForegroundColor White -NoNewline
  Write-Host $Status -ForegroundColor $Color
}

Write-Host "`nPREFETCH INTEGRITY`n" -ForegroundColor Gray

$PrefetchPath = "$($env:SystemRoot)\Prefetch"
Write-Host $TitleIndex "Prefetch status: " -ForegroundColor White -NoNewline

if (Test-Path $PrefetchPath) {
  $Files = Get-ChildItem -LiteralPath $PrefetchPath -Filter *.pf -Force

  $SuspiciousFiles = @{}
  $HashTable = @{}

  Write-Host "Scanning..." -ForegroundColor Yellow -NoNewline
  foreach ($File in $Files) {

    $Buffer = New-Object char[] 3
    
    $Reader = [System.IO.StreamReader]::new($File.FullName)
    $null = $Reader.ReadBlock($buffer, 0, 3)
    $reader.Close()

    $MAM = -join $Buffer

    $Hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    $IsHidden = $File.Attributes -band [System.IO.FileAttributes]::Hidden
    $Info = $File.Name

    if ($File.IsReadOnly -and $IsHidden) { 
      $SuspiciousFiles.Add($Info, "Read-Only and Hidden file") 
    }

    elseif ($File.IsReadOnly) {
      $SuspiciousFiles.Add($Info, "Read-Only file")
    }

    elseif ($IsHidden) {
      $SuspiciousFiles.Add($Info, "Hidden file")
    }
    
    if ($MAM -ne "MAM" -and -not $SuspiciousFiles.ContainsKey($File.Name)) {
      $SuspiciousFiles.Add($Info, "Does not contain 'MAM'")
    }

    if ($HashTable.ContainsKey($Hash)) { $HashTable[$Hash].Add($File.Name) }
    else {
      $HashTable[$Hash] = [System.Collections.Generic.List[string]]::new()
      $HashTable[$Hash].Add($Info)
    }
  }

  $HashTable.GetEnumerator() | 
    Where-Object { $_.Value.Count -gt 1 } | 
    ForEach-Object {
      foreach ($File in $_.Value) {
        if (-not $SuspiciousFiles.ContainsKey($File)) {
          $SuspiciousFiles.Add($File, "Duplicated hash")
        }
      }
    }

  Write-Host ("`r " * 30) -NoNewline
  Write-Host $TitleIndex "Prefetch status: " -ForegroundColor White -NoNewline

  if ($SuspiciousFiles.Count) {
    Write-Host "Suspicious" -ForegroundColor Red

    $SuspiciousFiles.GetEnumerator() | ForEach-Object {
      Write-Host $InforIndex ("{0,-25}: " -f $_.Value) -ForegroundColor Gray -NoNewline
      Write-Host $_.Key -ForegroundColor Red
    }
  } else { Write-Host "Prefetch folder is clean." -ForegroundColor Green }
} else { Write-Host "Prefetch folder not found." -ForegroundColor Red }

[System.Console]::Title = $OriginalTitle 