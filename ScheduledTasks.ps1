Clear-Host

Write-Host "Script by " -ForegroundColor White -NoNewline
Write-Host "aguacongas17`n" -ForegroundColor Red

$schedule = Get-CimInstance Win32_Service -Filter "Name='Schedule'" 
$startTime = (Get-Process -Id $schedule.ProcessId).StartTime
$state = $schedule.State
$startType = $schedule.StartMode

Write-Host "Schedule Integrity" -ForegroundColor DarkCyan
Write-Host "------------------"

Write-Host "State:      " -NoNewline
Write-Host $state -ForegroundColor Yellow

Write-Host "Start Type: " -NoNewline
Write-Host $startType -ForegroundColor Yellow

Write-Host "Start Time: " -NoNewline
Write-Host $startTime -ForegroundColor Yellow

Write-Host ""
Write-Host "Tasks scan" -ForegroundColor DarkCyan
Write-Host "----------"

$keywords = @(
    "cmd", "conhost", "java", "mshta",
    "-jar", "powershell", "msbuild",
    "taskmgr"
)

[Console]::CursorVisible = $false
$tasksPath = "$env:SystemDrive\Windows\System32\tasks"
$tasks = Get-ChildItem -LiteralPath $tasksPath -Recurse -Force -File -ErrorAction SilentlyContinue
$sResults = [Collections.Generic.List[object]]::new()
$results = [Collections.Generic.List[object]]::new()
$unknown = "-- Unknown --"
$counter = 1
$total = $tasks.count
$space = " " * 50

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

        $triggers = $content.Task.Triggers.ChildNodes.Name
        $author = $content.Task.RegistrationInfo.Author
        $author = if ($author) { $author } else { $unknown }

        $action = $content.Task.Actions.Exec
        $cmmd = $action.Command
        $args = $action.Arguments

        foreach ($keyword in $keywords) {
            if ($cmmd -like "*$keyword*" -or $args -like "*$keyword*") {
                $suspicious = $true
                $strings.Add($keyword)
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
        Write-Host "Access denied: " -ForegroundColor Red -NoNewline
        Write-Host $_.targetobject -ForegroundColor White

        continue
    }

    $fullTask = [PSCustomObject]@{
        Author      = $author
        Suspicious  = $suspicious
        URI         = $uri
        LastRunTime = $lastRun
        Command     = $cmmd
        Arguments   = $args
        Triggers    = $triggers
        Strings     = $strings
        Path        = $path
    }

    if ($suspicious) {
        $sResults.Add($fullTask)
    }

    $results.Add($fullTask)
    $counter++
}
Write-Host "`n"

$counter = 0
foreach ($result in $sResults) {
    if ($counter -eq 0) {
        Write-Host "¡Suspicious tasks found!" -ForegroundColor Red
        Write-Host "------------------------"
        $counter++
    }

    Write-Host "Task:        " -NoNewline
    Write-Host $result.Path -ForegroundColor Yellow

    Write-Host "Strings:     " -NoNewline
    Write-Host $result.Strings -ForegroundColor Yellow

    Write-Host "LastRunTime: " -NoNewline
    Write-Host $result.LastRunTime -ForegroundColor Yellow

    Write-Host ""
}
$results | Out-GridView -Title "Scheduled Tasks found"
pause
[Console]::CursorVisible = $true
