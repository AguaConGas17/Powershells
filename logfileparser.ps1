Clear-Host

$outputPath = "$env:TEMP\logfileExtract"
$rawcopyURI = "https://github.com/jschicht/RawCopy/releases/download/1.0.0.19/RawCopy_v1.0.0.19_.Win2000.zip"
$ntfslogURI = "https://github.com/AguaConGas17/Screenshare/raw/refs/heads/main/NTFS_Log_Tracker_CMDv1.9.zip"
$rawcopyOUT = "$outputPath\RawCopy.zip"
$ntfslogOUT = "$outputPath\NTFS_Log_Tracker.zip"
$rawcopyEXE = "$outputPath\RawCopy_v1.0.0.19_(Win2000)\RawCopy.exe"
$ntfslogEXE = "$outputPath\NTFS_Log_Tracker_CMD.exe"
$logfileOUT = "$outputPath\`$logfile"
$logfile = "$env:SystemDrive\`$logfile"

function Download-File($uri, $out) {
    try {
        Invoke-WebRequest -Uri $uri -UseBasicParsing -OutFile $out -ErrorAction Stop
        Expand-Archive -Path $out -DestinationPath $outputPath -Force
    }
    catch {
        Write-Host " > Error downloading or extracting '$uri' in '$out': $($_.exception)" -ForegroundColor Red
        exit
    }
}

Write-Host "[- LogFile Extractor -]" -ForegroundColor Blue
Write-Host " * Script by aguacongas17`n"

$null = New-Item -Path $outputPath -ItemType Directory -Force
Download-File -uri $rawcopyURI -out $rawcopyOUT
Download-File -uri $ntfslogURI -out $ntfslogOUT

Write-Host " > Extracting $logfile..." -NoNewline
$null = & $rawcopyEXE /FileNamePath:$logfile /OutputPath:$outputPath
Write-Host "`tDone" -ForegroundColor Green

Write-Host " > Parsing `$logfile and creating csv file..." -NoNewline
$null = & $ntfslogEXE -l $logfileOUT -o $outputPath -c
Write-Host "`tDone" -ForegroundColor Green

$logfilecsv = Get-Item -Path "$outputPath\NLT_LogFile*.csv"
$destination = "$env:SystemDrive\$($logfilecsv.Name)"

Move-Item -Path $logfilecsv -Destination $destination -Force
Write-Host " > CSV saved in $destination" -ForegroundColor Green
Remove-Item -Path $outputPath -Recurse -Force
