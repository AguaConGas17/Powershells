Clear-Host

[Console]::CursorVisible = $false

$Admin = [Security.Principal.WindowsBuiltInRole]::Administrator
$Current = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = [Security.Principal.WindowsPrincipal]::new($Current)

if (-not $Principal.IsInRole($Admin)) {
    Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor White -BackgroundColor Red
    Start-Sleep -Seconds 5
    exit
}

$keywords = @(
    "cmd", "conhost", "java", "mshta", "-jar", "powershell", "msbuild",
    "taskmgr", "type", "echo", "mmc", "start", "^", "regsvr32", "rundll32",
    "fsutil"
)
$falses = @(
    "BfeOnServiceStartTypeChange", "\Program Files\AMD\CNext\CNext\cncmd.exe",
    "\Program Files\AMD\CNext\CNext\RSServCmd.exe", "\Program Files\Microsoft OneDrive*OneDriveLauncher.exe",
    "%SystemRoot%\System32\dsregcmd.exe", "%systemroot%\System32\UsoClient.exe", "\Program Files\AMD\CIM\Bin64\InstallManagerApp.exe",
    "sc.exe start pushtoinstall login", "sc.exe start pushtoinstall registration", "sc.exe start w32time task_started",
    "%windir%\system32\PcaSvc.dll,PcaWallpaperAppDetect", "%windir%\system32\PcaSvc.dll,PcaPatchSdbTask", "config upnphost start= auto",
    "%systemroot%\system32\cmd.exe /d /c %systemroot%\system32\hpatchmonTask.cmd", 
    "%windir%\system32\rundll32.exe %windir%\system32\pcrpf.dll,NotifyFirmwareUpdateStaged",
    "%windir%\system32\rundll32.exe %windir%\system32\Windows.StateRepositoryClient.dll,StateRepositoryDoMaintenanceTasks",
    "%windir%\system32\rundll32.exe %windir%\system32\CapabilityAccessManager.dll,CapabilityAccessManagerDoStoreMaintenance",
    "%windir%\system32\rundll32.exe %windir%\system32\AppxDeploymentClient.dll,AppxPreStageCleanupRunTask", 
    "%systemroot%\System32\sc.exe start wuauserv", "\ProgramData\Microsoft\Windows Defender\Platform*MpCmdRun.exe"
)

$tasksPath = "$env:SystemDrive\Windows\System32\tasks"
$tasks = Get-ChildItem -LiteralPath $tasksPath -Recurse -Force -File -ErrorAction SilentlyContinue
$sResults = [Collections.Generic.List[object]]::new()
$results = [Collections.Generic.List[object]]::new()
$dAcc = [Collections.Generic.List[object]]::new()

$unknown = "-- Unknown --"
$counter = 1
$total = $tasks.count
$space = " " * 50
$skipped = 0

$schedule = Get-CimInstance Win32_Service -Filter "Name='Schedule'"
$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$state = $schedule.State
$startType = $schedule.StartMode   
$startTime = if ($schedule) { (Get-Process -Id $schedule.ProcessId).StartTime } else { $unknown }
$upTime = $startTime - $bootTime
$sUpTime = ("{0}h {1}m {2}s" -f $upTime.Hours, $upTime.Minutes, $upTime.Seconds)

Write-Host "Script by " -ForegroundColor White -NoNewline
Write-Host "aguacongas17`n" -ForegroundColor Red

Write-Host "Do you want to see only the suspicious tasks? (y/n): " -NoNewline
$onlyS = [Console]::ReadKey().KeyChar -like "y"
Write-Host "`n"

Write-Host "Schedule Integrity" -ForegroundColor DarkCyan
Write-Host "------------------"

Write-Host "Service State: " -NoNewline
Write-Host $state -ForegroundColor Yellow

Write-Host "Start Type:    " -NoNewline
Write-Host $startType -ForegroundColor Yellow

Write-Host "Start Time:    " -NoNewline
Write-Host $startTime -ForegroundColor Yellow -NoNewline
Write-Host " ($sUpTime after boot time)"

Write-Host ""
Write-Host "Tasks scan" -ForegroundColor DarkCyan
Write-Host "----------"

foreach ($task in $tasks) {
    $color = if ($total -eq $counter) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow } 
    
    Write-Host "`rScanning [" -NoNewline

    Write-Host $counter -ForegroundColor $color -NoNewline
    Write-Host "/" -NoNewline
    Write-Host $total -ForegroundColor Green -NoNewline

    Write-Host "]: " -NoNewline
    Write-Host $task.Name $space -ForegroundColor Yellow -NoNewline

    try {
        $path = $task.FullName
        $suspicious = $false
        $strings = [Collections.Generic.List[string]]::new()
        [xml]$content = Get-Content -LiteralPath $path -Raw -ErrorAction Stop

        $triggers = $content.Task.Triggers.ChildNodes.Name -join ", "
        $author = $content.Task.RegistrationInfo.Author
        $author = if ($author) { $author } else { $unknown }

        $action = $content.Task.Actions.Exec
        $cmmd = $action.Command
        $args = $action.Arguments
        $fullAc = "$cmmd $args"

        
        foreach ($keyword in $keywords) {
            if ($fullAc -like "*$keyword*") {
                $suspicious = $true
                foreach ($f in $falses) {
                    if ($fullAc -like "*$f*") {
                        $suspicious = $false
                        break
                    }
                }
                if ($suspicious) {
                    $strings.Add($keyword)
                }
                else {
                    $skipped++
                    $skip = "Skipped ($keyword)"
                    $strings.Add($skip)
                }
            }
        }
        if ($cmmd) {
            foreach ($cmd in $cmmd) {
                $cmd = $cmd.trim('"')
                if ($cmd.StartsWith("%")) {
                    $cmd = [Environment]::ExpandEnvironmentVariables($cmd)
                }

                $signature = (Get-AuthenticodeSignature -FilePath $cmd -ErrorAction SilentlyContinue).Status
                if ($signature) {
                    if ($signature -ne [Management.Automation.SignatureStatus]::Valid) {
                        $strings.Add("Unsigned File ($signature)")
                        $suspicious = $true
                        break
                    }
                }
                    
            }
        }

        try {
            $uri = $content.Task.RegistrationInfo.URI
            $info = Get-ScheduledTaskInfo -TaskName $uri -ErrorAction Stop
            $lastRun = $info.LastRunTime
        }
        catch {
            $lastRun = $unknown
        }
    }
    catch {
        $dAcc.Add($_)
        continue
    }

    $stringsF = $strings -join " <-> "

    $fullT = [PSCustomObject]@{
        Author      = $author
        LastRunTime = $lastRun
        Triggers    = $triggers
        Command     = $cmmd
        Arguments   = $args
        Suspicious  = $suspicious
        Strings     = $stringsF
        URI         = $uri
        Path        = $path
    }

    if ($suspicious) {
        $sResults.Add($fullT)
    }

    $results.Add($fullT)
    $counter++
}

Write-Host "`n"
Write-Host "Skipped Suspicious Tasks: $skipped"

foreach ($acc in $dAcc) {
    Write-Host "Access denied: " -ForegroundColor Red -NoNewline
    Write-Host $acc.targetobject -ForegroundColor White
}

if ($onlyS) {
    $sResults | Out-GridView -Title "Scheduled Tasks found (Only Suspicious)"
} 
else {
    $results | Out-GridView -Title "Scheduled Tasks found"
}

Write-Host "Press any button to exit..."
$null = [Console]::ReadKey()
[Console]::CursorVisible = $true
