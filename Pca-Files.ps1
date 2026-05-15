function ConvertFrom-UTC {
  param ( [string]$time )

  if ([string]::IsNullOrWhiteSpace($time)){ return $null }
  
  try{
    $date = [datetime]$time
    return [datetime]::SpecifyKind($date, [DateTimeKind]::Utc).ToLocalTime()
  } catch{ return $null }
}
function Get-Signature($path) { #function by diff xd
  if (-not (Test-Path -Path $path -PathType Leaf)) {
      return "NotFound"
  }
  try {
      $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromSignedFile($path)
      $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $cert
      $cheatSignatures = @("manthe industries, llc", "slinkware", "amstion limited", "newfakeco", "faked signatures inc")
      foreach ($cheat in $cheatSignatures) {
          if ($cert2.Subject.ToLower().Contains($cheat.ToLower())) {
              return "Cheat Signature"
          }
      }
      $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
      $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
      $chain.ChainPolicy.VerificationFlags = [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::AllowUnknownCertificateAuthority -bor [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::IgnoreNotTimeValid
      $isValid = $chain.Build($cert2)
      if ($isValid -and $chain.ChainElements.Count -gt 1) {
          return "Signed"
      } elseif ($cert2.Subject -eq $cert2.Issuer) {
          return "Fake Sig"
      } else {
          return "Fake Sig"
      }
  } catch {
      return "Unsigned"
  }
}
$logonT = (Get-CimInstance Win32_LogonSession -filter LogonType=2 | Sort StartTime | Select -Last 1).StartTime.ToString("HH:mm:ss dd-MM-yyyy")
$paths = @("C:\Windows\appcompat\pca\PcaAppLaunchDic.txt", "C:\Windows\appcompat\pca\PcaGeneralDb0.txt")
$response = @()

Write-Host "Do you want read PcaAppLaunchDic? (y/n): " -NoNewline
$response += [console]::ReadKey()
Write-Host ""

Write-Host "Do you want read PcaGeneralDb0? (y/n): " -NoNewline
$response += [console]::ReadKey()
Write-Host ""

if ($response[0].key -eq "y"){
  if (Test-Path $paths[0]){
    $output = switch -File $paths[0]{
      { [string]::IsNullOrWhiteSpace($_) } { continue }
      default{
        $line = $_ -split "\|"

        [PSCustomObject]@{
          Path = $line[0]
          Signature = Get-Signature -Path $line[0]
          ExecutionTime = ConvertFrom-UTC -time $line[1]
        }
      }
    }
    $output | Out-GridView -Title "$($paths[0]) results. LogonTime: $logonT"
  } else { Write-Host -f Red "File $($paths[0]) doesn't exist." }
}
if ($response[1].key -eq "y"){
  if (Test-Path $paths[1]){
    $output = switch -File $paths[1]{
      { [string]::IsNullOrWhiteSpace($_) } { continue }
      default{
        $line = $_ -split "\|"
        $path = [System.Environment]::ExpandEnvironmentVariables($line[2])

        [PSCustomObject]@{
          Path          = $path
          Signature     = Get-Signature -Path $path
          ExecutionTime = ConvertFrom-UTC -time $line[0]
          RunStatus     = $line[1]
          Product       = $line[3]
          Copyright     = $line[4]
          Version       = $line[5]
          ProgramID     = $line[6]
          ExitCode      = $line[7]
        }
      }
    }
    $output | Out-GridView -Title "$($paths[1]) results. LogonTime: $logonT"
  } else { Write-Host -f Red "File $($paths[1]) doesn't exist." }
}

Pause