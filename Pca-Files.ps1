using namespace System.Security.Cryptography.X509Certificates
function Get-Signature($path) {
    try {
        $cheatSignatures = @(
            "manthe industries, llc", "slinkware", "amstion limited", "newfakeco", 
            "prestige software development","faked signatures inc")
        $cert = [X509Certificate2]::CreateFromSignedFile($path)
        $signer = $cert.Subject.ToLower()
        
        foreach ($signature in $cheatSignatures) {
            if ($signer.Contains($signature)) {
                return "CheatSignature"
            }
        }

        $chain = [X509Chain]::new()
        $chain.ChainPolicy.VerificationFlags = [X509VerificationFlags]::IgnoreNotTimeValid
        $valid = $chain.Build($cert)

        if ($valid -and $chain.ChainElements.Count -gt 1) { 
            return "Signed" 
        }
        elseif ($signer -eq $cert.Issuer) { 
            return "FakeSignature" 
        }
        else { return "FakeSignature" }
    }
    catch { return "Unsigned" }
}

$osVersion = Get-CimInstance Win32_OperatingSystem | Select-Object @{ Name = "Version"; Expression = { [version]$_.version } }, Caption
$logonTime = (Get-CimInstance Win32_LogonSession -Filter "LogonType='2'" | Sort-Object StartTime -Descending)[0].StartTime
$pcaPath = "$env:SystemRoot\appcompat\pca"
$pcaGeneral = @{
    Path = "$pcaPath\PcaGeneralDb0.txt"
    Encoding = [System.Text.Encoding]::Unicode 
    Headers = @("ExecutionTime (Local)", "RecordType", "FilePath", "ProductName", "CompanyName", "ProductVersion", "ProgramID", "Message", "Signature")
}
$pcaAppLaunchDic = @{
    Path = "$pcaPath\PcaAppLaunchDic.txt"
    Encoding = [System.Text.Encoding]::Default 
    Headers = @("FilePath", "ExecutionTime (Local)", "Signature")
}

Write-Host ("Detected Windows version: " + $osVersion.Caption)

if ($osVersion.Version.Build -lt 22000) {
    Write-Host "$pcaPath is available only on Windows 11 and later..."
    exit
}

foreach ($pcaLog in @($pcaGeneral, $pcaAppLaunchDic)) {
    $logExistence = Test-Path -LiteralPath $pcaLog.Path
    if ($logExistence) {
        $content = [System.IO.File]::ReadAllLines($pcaLog.Path, $pcaLog.Encoding)
        $csvContent = ConvertFrom-Csv -InputObject $content -Delimiter "|" -Header $pcaLog.Headers
        
        Write-Host $content.count lines found in $pcaLog.Path
    
        foreach ($entrie in $csvContent) {
            $filePath = $entrie.FilePath
            [datetime]$executionTime = $entrie."ExecutionTime (Local)"
            $signature = "NotFound"
    
            if ($filePath.StartsWith("%")) {
                $match = [regex]::Match($filePath, "(%.+%)")
    
                if (!$match.Success) { continue }
    
                $newValue = [System.Environment]::ExpandEnvironmentVariables($match.Value)
                $filePath = ($filePath -replace $match.Value, $newValue)
            }
            if (
                $filePath.StartsWith("\") -and 
                $filePath -notlike "\\?\Volume*"
            ) {
                $filePath = $env:SystemDrive + $filePath
            }
    
            $existence = Test-Path -LiteralPath $filePath
            if ($existence) { 
                $signature = Get-Signature $filePath 
            }
    
            $entrie.FilePath = $filePath
            $entrie.Signature = $signature
            $entrie."ExecutionTime (Local)" = $executionTime.ToLocalTime()
        }
    
        $csvContent | Out-GridView -Title ($pcaLog.Path + " - LogonTime: $logonTime")
    }
    else {
        Write-Host ("The file " + $pcaLog.Path + " was not found...")
    }
}
