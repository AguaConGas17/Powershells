Clear-Host

Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Host "Script by aguacongas17 =)`n" -ForegroundColor DarkBlue

function Get-FileJournal($filePath) {
    $fileName = [System.IO.Path]::GetFileName($filePath)
    $directory = [System.IO.Path]::GetDirectoryName($filePath)
    $fileRoot = [System.IO.Path]::GetPathRoot($filePath).trim("\")

    $output = "$env:TEMP\journal.csv"

    $null = & $script:journalPath $fileRoot -L -n $fileName -f csv -o $output

    $journal = ConvertFrom-Csv -InputObject (Get-Content -LiteralPath $output)
    $fileID = ($journal.Where( { $_.Name -eq $fileName -and $_.Directory -eq $directory } ))[0]."File ID"
    $fileInfo = $journal.Where({ $_."File ID" -eq $fileID })

    return $fileInfo
}
function Get-JarFlags($jarPath) {
    $flagA = $false 
    $flagB = $false 
    $flagC = $false 
    $flags = [Collections.Generic.List[string]]::new()

    $flagAKeywords = @(
        "clicker", "fasttotem", "jesus", "timer", "nuker", "tracers", "xray", "speedmine", "airplace", 
        "velocity", "timer", "scaffold", "noslow", "blink", "freecam", "aimbot", "selfdestruct", "ghostclient", 
        "killaura", "crystalaura", "anchoraura", "autototem", "autoarmor", "autotrap", "autoweb", "autogap", 
        "autojump"  , "autoclicker", "autoclick"
    )
    $flagCKeywords = @(
        "com/ruffian7/sevenclicker/AutoClicker.class", "me/dewgs/clicker/Main.class", "meteordevelopment/meteorclient/MeteorClient.class"
    )
    $doomsdayStructure = @(
        "mod_d.class", "net/java/f.class", "net/java/g.class", "net/java/h.class", "net/java/i.class", "net/java/k.class",
        "net/java/l.class", "net/java/n.class", "net/java/r.class", "net/java/s.class", "net/java/t.class", "net/java/y.class"
    )
    
    try {
        $jarContent = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        $jarClasses = $jarContent.entries.Where({$_.Name -like "*.class"})
        $classesPath = $jarClasses.fullname
        $totalClasses = $jarClasses.count
        $obfuscatedClasses = 0

        foreach ($class in $jarClasses) {
            if (!$flagA) {
                foreach ($cheat in $flagaKeywords) {
                    $kw = "*$cheat*"

                    if ($class.Name -like $kw) {
                        $flagA = $true
                        $flags.Add("Flag A")
                        break
                    }
                } 
            }

            if (!$flagB) {
                if ($class.Name.Length -le 7) {
                    $obfuscatedClasses++
                }

                if ($obfuscatedClasses -ge (0.4*$totalClasses)) {
                    $flagB = $true
                    $flags.Add("Flag B")
                }
            }

            if (!$flagC) {
                foreach ($cheatClass in $flagCKeywords) {
                    if ($classesPath.contains($cheatClass)) {
                        $flagC = $true
                        break
                    }
                }
                
                if (
                    !(Compare-Object -ReferenceObject $doomsdayStructure -DifferenceObject $classesPath) -and
                    $jarContent.entries.name.contains("l.png")
                ) {
                    $flagC = $true
                }

                if ($flagC) {
                    $flags.Add("Flag C")
                }
            }
        }
    }
    catch {}
    finally {
        if ($jarContent) {
            $jarContent.dispose()
        }
    }

    return ($flags -join " | ")
}
function Find-FileReplaces($filePath) {
    $fileName = [System.IO.Path]::GetFileName($filePath)
    $directory = [System.IO.Path]::GetDirectoryName($filePath)  
    
    $fileID = ($script:journalReplaces.Where( { $_.Name -eq $fileName -and $_.Directory -eq $directory } ))[0]."File ID"
    if (!$fileID) { return }

    $fileInfo = $script:journalReplaces.Where({ $_."File ID" -eq $fileID })
    $events = @(Get-FileJournal $filePath)

    return $fileInfo += [pscustomobject]@{"Events" = $events}
}

$logonTime = (Get-CimInstance Win32_LogonSession -Filter "LogonType='2'" | Sort-Object StartTime -Descending)[0].StartTime
$prefetchPath = "$env:SystemRoot\Prefetch"
$javaPrefetch = Get-ChildItem -LiteralPath $prefetchPath -Filter "java*.pf" | Where-Object { $_.LastWriteTime -ge $logonTime }
$volumeMap = @{}
$volumes = Get-CimInstance Win32_Volume

$pecmdURI = "https://github.com/AguaConGas17/Screenshare/raw/refs/heads/main/PECmd.exe"
$xxstrURI = "https://github.com/ZaikoARG/xxstrings/releases/download/1.0.0/xxstrings64.exe"
$journalURI = "https://github.com/Orbdiff/USNJournal_CLI/releases/download/v1.0.1/Journal_CLI.exe"
$pecmdPath = "$env:TEMP\pecmd.exe"
$xxstrPath = "$env:TEMP\xxstrings64.exe"
$journalPath = "$env:TEMP\Journal_CLI.exe"

try {
    $null = Invoke-WebRequest -Uri $pecmdURI -UseBasicParsing -OutFile $pecmdPath -ErrorAction Stop
    $null = Invoke-WebRequest -Uri $xxstrURI -UseBasicParsing -OutFile $xxstrPath -ErrorAction Stop
    $null = Invoke-WebRequest -Uri $journalURI -UseBasicParsing -OutFile $journalPath -ErrorAction Stop
}
catch {
    Write-Host "[-] Error downloading tools ($($_.targetobject.requesturi.absoluteuri))..." -ForegroundColor Red 
    exit
}

foreach ($volume in $volumes) {
   $drive = $volume.driveLetter
   if ($drive) {
      $serial = "{0:x}" -f $volume.serialNumber
      $volumeMap[$serial] = $drive
   }
}

Write-Host "{ Prefetch Files }" -ForegroundColor Blue -NoNewline
Write-Host " (Only results from after the logon time)" -ForegroundColor DarkGray
if ($javaPrefetch) {
    $pathsFound = [Collections.Generic.List[string]]::new()
    $unknown = [Collections.Generic.List[string]]::new()
    $validJAR = [Collections.Generic.List[string]]::new()

    $replacesOutput = "$env:TEMP\replaces_combined.csv"
    $null = & $journalPath $env:SystemDrive -L -x all --only-replace --combine-replaces -f csv -o $replacesOutput
    $journalReplaces = ConvertFrom-Csv -InputObject (Get-Content -LiteralPath $replacesOutput)

    foreach ($prefetch in $javaPrefetch) {
        $pfPath = $prefetch.FullName
        $name = $prefetch.Name
        $lwt = $prefetch.LastWriteTime
        $output = "$env:TEMP\$name.json"

        $null = & $pecmdPath -f $pfPath -q --json $env:TEMP --jsonf "$name.json"
        $existence = Test-Path -LiteralPath $output 

        if ($existence) {
            $content = ConvertFrom-Json -InputObject (Get-Content -LiteralPath "$env:TEMP\$name.json")
            $runcount = $content.RunCount
            $imports = $content.FilesLoaded.Split(",").TrimStart(" ")

            foreach ($import in $imports) {
                if ($import -match "\\VOLUME{[0-9A-Fa-f\-]+-([0-9a-f]+)}\\(.+)") {
                    $serial = $Matches[1]
                    $directory = $Matches[2]
                    
                    if ($volumeMap.ContainsKey($serial)) {
                        $path = "$($volumeMap[$serial])\$directory"
                    }
                    else {
                        $path = $import
                    }

                    $pathsFound.Add($path)
                }
            }

            Write-Host "$pfPath`t" -ForegroundColor Green
            Write-Host " > Modified Time: $lwt"
            Write-Host " > Run Count: $runcount"
        }
    }
    Write-Host "`n{ Imports Found }" -ForegroundColor Blue
    foreach ($path in $pathsFound) {
        if(!(Test-Path -LiteralPath $path)) {
            $fileInformation = Get-FileJournal $path

            if ($fileInformation) {
                Write-Host "[-] Deleted: $path" -ForegroundColor Yellow

                $event = $fileInformation | Select-Object -Last 1
                $fullname = "$($event.Directory)\$($event.Name)"
                $date = $event.Date
                $reason = $event.Reason

                Write-Host "`tDeleted as '$fullname'"
                Write-Host "`t$reason ($date)"
            }
            continue
        }
        else {
            try {
                $stream = [System.IO.File]::OpenRead($path)

                $bytes = New-Object byte[] 4
                $null = $stream.Read($bytes, 0, 4)
                $magicNumber = [BitConverter]::ToString($bytes)
                $stream.dispose()
            }
            catch {
                $unknown.Add($path)
                if ($stream) {
                    $stream.dispose()
                }
                continue
            }

            if ($magicNumber -notin @("50-4B-03-04", "CA-FE-BA-BE")) {
                $fileInformation = Find-FileReplaces $path

                if ($fileInformation) {
                    $type = "$($fileInformation.type)".TrimEnd(" ")
                    
                    Write-Host "[X] Replaced file ($type): $path" -ForegroundColor DarkRed
                    
                    foreach ($event in $fileInformation.Events) {
                        if (!$event) { continue }
                        $fullname = "$($event.Directory)\$($event.Name)"
                        $date = $event.Date
                        $reason = $event.Reason
    
                        Write-Host "`t$fullname $reason ($date)"
                    }
                }
                continue
            }
        }
        
        if ($path -notlike "*.jar" -and $path -notlike "*.zip") {
            Write-Host "[x] Modified extension: $path" -ForegroundColor Red
        }
        else {
            $fileInformation = Find-FileReplaces $path
            if ($fileInformation) {
                $type = "$($fileInformation.type)".TrimEnd(" ")
                
                Write-Host "[X] Replaced file ($type): $path" -ForegroundColor DarkRed
                
                foreach ($event in $fileInformation.Events) {
                    if (!$event) { continue }
                    $fullname = "$($event.Directory)\$($event.Name)"
                    $date = $event.Date
                    $reason = $event.Reason

                    Write-Host "`t$fullname $reason ($date)"
                }
            }
            else {
                if ($path -like "*.zip") {
                    $isZip = $true

                    try {
                        $zipContent = [System.IO.Compression.ZipFile]::OpenRead($path)
                        $isZip = !($zipContent.entries.fullname.contains("META-INF/MANIFEST.MF"))
                    }
                    catch {}
                    finally {
                        if ($zipContent) {
                            $zipContent.dispose()
                        }
                    }

                    if (!$isZip) {
                        Write-Host "[x] Modified extension: $path" -ForegroundColor Red
                    }

                    continue
                }

                $validJAR.Add($path)
            }
        }
    }
    foreach ($jarPath in $validJAR) {
        $flags = Get-JarFlags $jarPath
        Write-Host "[+] Valid Jar: $jarPath" -ForegroundColor Green -NoNewline
        Write-Host " $flags" -ForegroundColor DarkGray
    }
    Write-Host "[!] Can't read: " -ForegroundColor Red -NoNewline
    Write-Host (($unknown | Select-Object -Unique) -join ", ")
}
else {
    Write-Host "[*] No java/w prefetch found after logon: $logonTime"
}

Write-Host "`n{ Prefetch Integrity }" -ForegroundColor Blue

$fullPrefetch = Get-ChildItem -LiteralPath $prefetchPath -Force
$prefetchHashes = @{}
$modifiedPF = "$env:TEMP\ModifiedPFFiles.csv"
$null = & $journalPath $env:SystemDrive -L -n ".pf" -r "File Delete;Rename" -p $prefetchPath -f csv -o $modifiedPF
$journalPF = ConvertFrom-Csv -InputObject (Get-Content -LiteralPath $modifiedPF)

if ($journalPF) {
    $counter = 0
    foreach ($event in $journalPF) {
        $pfPath = "$($event.Directory)\$($event.Name)"
        $date = $event.Date
        $reason = $event.Reason

        Write-Host "[x] Modified PF found: " -ForegroundColor Yellow -NoNewline
        Write-Host "$pfPath -> $reason ($date)"

        $counter++
        if ($counter -eq 3) {
            $more = $journalPF.count - $counter
            Write-Host "[!] And $more more..." -ForegroundColor Yellow
            break
        }
    }
}
else {
    Write-Host "[+] No modified PF files found (journal)" -ForegroundColor Green
}
if ($fullPrefetch) {
    foreach ($pf in $fullPrefetch) {
        $name = $pf.fullname
        $hash = (Get-FileHash -Path $name -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash

        if ($pf.Attributes -band [IO.FileAttributes]::Hidden) {
            Write-Host "[x] Hidden PF file: $name" -ForegroundColor Red
        }
        if ($pf.IsReadOnly) {
            Write-Host "[x] Read-Only PF file: $name" -ForegroundColor Red
        }
        if ($hash) {
            if (!$prefetchHashes.ContainsKey($hash)) {
                $prefetchHashes[$hash] = [Collections.Generic.List[string]]::new()
            }

            $prefetchHashes[$hash].Add($name)
        }
    }

    $duplicatedHash = $prefetchHashes.GetEnumerator().Where({ $_.Value.Count -gt 1 })
    foreach ($duplicated in $duplicatedHash) {
        Write-Host "[X] Duplicated Hash: $($duplicated.Value -join " -> ")" -ForegroundColor DarkRed
    }
}

Write-Host "`n{ Process Memory Strings }" -ForegroundColor Blue
foreach ($service in @("Diagtrack", "PcaSvc", "DcomLaunch")) {
    $procID = (Get-CimInstance Win32_Service -Filter "Name='$service'").ProcessID
    $rawstrings = & $xxstrPath -p $procID -raw
    $strings = $rawstrings.Where({ $_.contains("-jar") }) | Select-Object -Unique


    if ($strings) {
        $type = $strings.GetType().fullname
        Write-Host "[X] Strings found in $service`:" -ForegroundColor DarkRed

        if ($type -eq "System.Object[]") {
            for ($i = 0; $i -lt $strings.count; $i++) {
                $cString = $strings[$i]
                Write-Host "`t$cstring"
            }
        }
        else {
            Write-Host "`t$strings" -ForegroundColor Red
        }
    }
    else {
        Write-Host "[+] No strings found in $service" -ForegroundColor Green
    }
}
