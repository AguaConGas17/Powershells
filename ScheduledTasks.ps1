Clear-Host

[Console]::CursorVisible = $false

$admin = [Security.Principal.WindowsBuiltInRole]::Administrator
$current = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($Current)

if (-not $principal.IsInRole($admin)) {
    Write-Host "ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor White -BackgroundColor Red
    Start-Sleep -Seconds 5
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$keywords = @(
    "cmd", "conhost", "java", "mshta", "jar", "powershell", "msbuild",
    "taskmgr", "type", "echo", "mmc", "start", "^", "regsvr32", "rundll32",
    "fsutil", "icacls", "python", "reg", "copy", "installutil", "curl", "cdb",
    ".bat", ".ps1"
)
$falses = @(
    "BfeOnServiceStartTypeChange", "\Program Files\AMD\CNext\CNext\cncmd.exe",
    "\Program Files\AMD\CNext\CNext\RSServCmd.exe", "\Program Files\Microsoft OneDrive*OneDriveLauncher.exe",
    "\AppData\Local\Microsoft\OneDrive*OneDriveLauncher.exe", "--producttype", "%windir%\System32\AppHostRegistrationVerifier.exe",
    "%SystemRoot%\System32\dsregcmd.exe", "%systemroot%\System32\UsoClient.exe", "\Program Files\AMD\CIM\Bin64\InstallManagerApp.exe",
    "sc.exe start pushtoinstall login", "sc.exe start pushtoinstall registration", "sc.exe start w32time task_started",
    "%windir%\system32\PcaSvc.dll,PcaWallpaperAppDetect", "%windir%\system32\PcaSvc.dll,PcaPatchSdbTask", "config upnphost start= auto",
    "%systemroot%\system32\cmd.exe /d /c %systemroot%\system32\hpatchmonTask.cmd", "\Windows\System32\agentactivationruntimestarter.exe",
    "%windir%\system32\rundll32.exe %windir%\system32\pcrpf.dll,NotifyFirmwareUpdateStaged", "\Windows\System32\sc.exe start wuauserv",
    "%windir%\system32\rundll32.exe %windir%\system32\Windows.StateRepositoryClient.dll,StateRepositoryDoMaintenanceTasks",
    "%windir%\system32\rundll32.exe %windir%\system32\CapabilityAccessManager.dll,CapabilityAccessManagerDoStoreMaintenance",
    "%windir%\system32\rundll32.exe %windir%\system32\AppxDeploymentClient.dll,AppxPreStageCleanupRunTask",
    "%windir%\System32\Windows.SharedPC.AccountManager.dll,StartMaintenance", "%windir%\system32\bcdboot.exe %windir% /sysrepair",
    "%systemroot%\System32\sc.exe start wuauserv", "\ProgramData\Microsoft\Windows Defender\Platform*MpCmdRun.exe"
)
$cheatsSig = @(
    "manthe industries, llc", "slinkware", "amstion limited", 
    "newfakeco", "faked signatures inc"
)

$tasksPath = "$env:SystemDrive\Windows\System32\Tasks"
$tasks = Get-ChildItem -LiteralPath $tasksPath -Recurse -Force -File -ErrorAction SilentlyContinue
$results = [Collections.Generic.List[object]]::new()
$dAcc = [Collections.Generic.List[object]]::new()

$unknown = "-- Unknown --"
$username = $env:USERNAME
$counter = 1
$total = $tasks.count
$skipped = 0

$schedule = Get-CimInstance Win32_Service -Filter "Name='Schedule'"
$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$state = $schedule.State
$startType = $schedule.StartMode   
$startTime = if ($schedule) { (Get-Process -Id $schedule.ProcessId).StartTime } else { $unknown }
$upTime = $startTime - $bootTime
$sUpTime = ("{0}h {1}m {2}s" -f $upTime.Hours, $upTime.Minutes, $upTime.Seconds)

$journalCLI = "$env:TEMP\Journal_CLI.exe"
$journalOUT = "$env:TEMP\journal.txt"
$replacesOUT = "$env:TEMP\replaces_combined.txt"
$journalURI = "https://github.com/Orbdiff/USNJournal_CLI/releases/download/v1.0.1/Journal_CLI.exe"
$time = $bootTime.ToString("yyyy-MM-dd HH:mm:ss")

try {
    $null = Remove-Item $journalOUT -ErrorAction SilentlyContinue
    $null = Remove-Item $replacesOUT -ErrorAction SilentlyContinue

    $null = Invoke-WebRequest -Uri $journalURI -UseBasicParsing -OutFile $journalCLI -ErrorAction Stop
    $null = & $journalCLI $env:SystemDrive -A $time -r "File Delete" -p $tasksPath -R -f txt -o $journalOUT
    $null = & $journalCLI $env:SystemDrive -A $time -p $tasksPath -R -x all --only-replace --combine-replaces -f txt --output-dir $env:TEMP
    $replaces = (Get-Content -Path $replacesOUT -ErrorAction SilentlyContinue).Split("")
}
catch {
    Write-Host "Error downloading: $journalURI (USNJournal won't be scanned for replaced or deleted tasks)`n"
}

Write-Host "discord.gg/ssa - Script by " -ForegroundColor White -NoNewline
Write-Host "aguacongas17 :)`n" -ForegroundColor Red

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
    $space = [Console]::WindowWidth - 21
    $nameL = $task.Name.Length
    $color = if ($total -eq $counter) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow } 
    $name = if ($nameL -gt $space) { $task.Name.Substring(0, $space - 3) + "..." } else { $task.Name + (" " * ($space - $nameL)) }

    Write-Host "`rScanning [" -NoNewline

    Write-Host $counter -ForegroundColor $color -NoNewline
    Write-Host "/" -NoNewline
    Write-Host $total -ForegroundColor Green -NoNewline

    Write-Host "]: " -NoNewline
    Write-Host $name -ForegroundColor Yellow -NoNewline

    try {
        $path = $task.FullName
        $suspicious = $false
        $replaced = $false
        $strings = [Collections.Generic.List[string]]::new()
        [xml]$content = Get-Content -LiteralPath $path -Raw -ErrorAction Stop

        $triggers = $content.Task.Triggers.ChildNodes.Name -join ", "
        $author = $content.Task.RegistrationInfo.Author
        $author = if ($author) { $author } else { $unknown }

        $action = $content.Task.Actions.Exec
        $cmmd = $action.Command
        $args = $action.Arguments
        $fullAc = "$cmmd $args"

        try {
            $uri = $content.Task.RegistrationInfo.URI
            $info = Get-ScheduledTaskInfo -TaskName $uri -ErrorAction Stop
            $lastRun = $info.LastRunTime
        }
        catch {
            $lastRun = $unknown
        }
        
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

                $signature = Get-AuthenticodeSignature -FilePath $cmd -ErrorAction SilentlyContinue
                $status = $signature.Status
                if ($signature) {
                    if ($status -ne [Management.Automation.SignatureStatus]::Valid) {
                        $strings.Add("Unsigned File ($status)")
                        $suspicious = $true
                        break
                    }
                    foreach ($sig in $cheatsSig) {
                        if ($signature.SignerCertificate.Subject -like "*$sig*") {
                            $strings.Add("Cheat Signature")
                            $suspicious = $true
                            break
                        }
                    }
                }       
            }
        }

        if ($replaces) {
            if ($replaces -contains $uri.TrimStart("\")) {
                $suspicious = $true
                $replaced = $true
            }
        }
    }
    catch {
        $dAcc.Add($_)
        continue
    }

    $stringsF = $strings -join " <-> "
    $args = $args -join ", "
    $cmmd = $cmmd -join ", "

    $fullT = [PSCustomObject]@{
        Author      = $author
        LastRunTime = $lastRun
        Triggers    = $triggers
        Command     = $cmmd
        Arguments   = $args
        Replaced    = $replaced
        Suspicious  = $suspicious
        Strings     = $stringsF
        URI         = $uri
        Path        = $path
    }

    $results.Add($fullT)
    $counter++
}

Write-Host "`nSkipped strings: $skipped"

foreach ($acc in $dAcc) {
    Write-Host "Access denied: " -ForegroundColor Red -NoNewline
    Write-Host $acc.targetobject -ForegroundColor White
}

[Console]::CursorVisible = $true

$form = [Windows.Forms.Form]::new()
$form.Text = "Scheduled Tasks found"
$form.WindowState = "Maximized"
$form.BackColor = [Drawing.Color]::WhiteSmoke
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AguaConGas17/randomassets/main/ssalogo.png" -UseBasicParsing -OutFile "$env:TEMP\ssalogo.png" -ErrorAction Stop
    $bitmap = [Drawing.Bitmap]::new("$env:TEMP\ssalogo.png")
    $form.Icon = [Drawing.Icon]::FromHandle($bitmap.GetHicon())
}
catch {
    $form.ShowIcon = $false
}

$dataGV = [Windows.Forms.DataGridView]::new()
$dataGV.Dock = "Fill"
$dataGV.RowHeadersWidth = 25
$dataGV.AutoSizeColumnsMode = "DisplayedCells"
$dataGV.ScrollBars = "Both"
$dataGV.AllowUserToAddRows = $false
$dataGV.ReadOnly = $true
$dataGV.BackgroundColor = [Drawing.Color]::LightSteelBlue
$dataGV.GridColor = [Drawing.Color]::Gray
$dataGV.ColumnHeadersDefaultCellStyle.BackColor = [Drawing.Color]::SteelBlue
$dataGV.ColumnHeadersDefaultCellStyle.ForeColor = [Drawing.Color]::Black
$dataGV.ColumnHeadersDefaultCellStyle.Font = [Drawing.Font]::new("Segoe UI", 10, [Drawing.FontStyle]::Bold)
$dataGV.DefaultCellStyle.BackColor = [Drawing.Color]::Gainsboro
$dataGV.DefaultCellStyle.ForeColor = [Drawing.Color]::Navy
$dataGV.DefaultCellStyle.Font = [Drawing.Font]::new("Arial", 9, [Drawing.FontStyle]::Regular)
$form.Controls.Add($dataGV)

$panel = [Windows.Forms.Panel]::new()
$panel.Dock = "Top"
$panel.Height = 30
$panel.BackColor = [Drawing.Color]::LightSteelBlue
$form.Controls.Add($panel)

$sLabel = [Windows.Forms.Label]::new()
$sLabel.Text = "Search in columns:"
$sLabel.Font = [Drawing.Font]::new("Segoe UI", 10, [Drawing.FontStyle]::Bold)
$sLabel.Location = [Drawing.Point]::new(10, 7)
$sLabel.AutoSize = $true
$panel.Controls.Add($sLabel)

$sBox = [Windows.Forms.TextBox]::new()
$sBox.Location = [Drawing.Point]::new(135, 7)
$sBox.BackColor = [Drawing.Color]::Gainsboro
$sBox.Width = 200
$panel.Controls.Add($sBox)

$sCB = [Windows.Forms.CheckBox]::new()
$sCB.Text = "Only Suspicious"
$sCB.Location = [Drawing.Point]::new(340, 10)
$sCB.Checked = $false
$sCB.AutoSize = $true
$panel.Controls.Add($sCB)

$mtCB = [Windows.Forms.CheckBox]::new()
$mtCB.Text = "Manual Tasks"
$mtCB.Location = [Drawing.Point]::new(450, 10)
$mtCB.Checked = $false
$mtCB.AutoSize = $true
$panel.Controls.Add($mtCB)

$dButton = [Windows.Forms.Button]::new()
$dButton.Text = "View deleted tasks"
$dButton.Width = 150
$dButton.Location = [Drawing.Point]::new(700, 5)
$dButton.Font = [Drawing.Font]::new("Segoe UI", 10, [Drawing.FontStyle]::Bold)
$dButton.BackColor = [Drawing.Color]::SteelBlue
$dButton.Add_Click({ & notepad.exe $journalOUT })
$panel.Controls.Add($dButton)

$rButton = [Windows.Forms.Button]::new()
$rButton.Text = "View replaced tasks"
$rButton.Width = 150
$rButton.Location = [Drawing.Point]::new(550, 5)
$rButton.Font = [Drawing.Font]::new("Segoe UI", 10, [Drawing.FontStyle]::Bold)
$rButton.BackColor = [Drawing.Color]::SteelBlue
$rButton.Add_Click({ & notepad.exe $replacesOUT })
$panel.Controls.Add($rButton)


$dataT = [Data.DataTable]::new()
$null = $dataT.Columns.Add("Author", [string])
$null = $dataT.Columns.Add("LastRunTime", [datetime])
$null = $dataT.Columns.Add("Triggers", [string])
$null = $dataT.Columns.Add("Command", [string])
$null = $dataT.Columns.Add("Arguments", [string])
$null = $dataT.Columns.Add("Replaced", [bool])
$null = $dataT.Columns.Add("Suspicious", [bool])
$null = $dataT.Columns.Add("Strings", [string])
$null = $dataT.Columns.Add("URI", [string])
$null = $dataT.Columns.Add("Path", [string])

foreach ($result in $results) {
    $row = $dataT.NewRow()

    $row.Author = $result.Author
    $row.LastRunTime = $result.LastRunTime
    $row.Triggers = $result.Triggers
    $row.Command = $result.Command
    $row.Arguments = $result.Arguments
    $row.Replaced = $result.Replaced
    $row.Suspicious = $result.Suspicious
    $row.Strings = $result.Strings
    $row.URI = $result.URI
    $row.Path = $result.Path
    
    $dataT.Rows.Add($row)
}

$dataView = [Data.DataView]::new($dataT)
$dataGV.DataSource = $dataView

function Update-Filter {
    $text = $sBox.Text

    $filter = [Collections.Generic.List[string]]::new()

    if ($sCB.Checked) {
        $filter.Add("Suspicious = True")
    }

    if ($mtCB.Checked) {
        $filter.Add("Author LIKE '%$username%'")
    }
    
    if ($text -ne "") {
        $filter.Add("(Triggers LIKE '%$text%' OR Command LIKE '%$text%' OR Arguments LIKE '%$text%' OR 
        Strings LIKE '%$text%' OR URI LIKE '%$text%' OR Path LIKE '%$text%')")
    }

    $dataView.RowFilter = $filter -join " AND "
}

$sBox.Add_TextChanged({ Update-Filter })
$sCB.Add_CheckedChanged({ Update-Filter })
$mtCB.Add_CheckedChanged({ Update-Filter })
Update-Filter

$null = $form.ShowDialog()
