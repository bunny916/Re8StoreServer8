<#
.SYNOPSIS
    Automated installer for 8Store (Re8Store) with self-signed certificate trust setup.
.DESCRIPTION
    Imports the CN=Ibrahim root certificate into Local Machine Trusted Root and Trusted People
    certificate stores, then installs the 8Store AppX package via Add-AppxPackage.
#>

# 1. Self-elevate to Administrator if not elevated
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating permissions to install certificate into Local Machine store..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        exit $proc.ExitCode
    } catch {
        Write-Error "Administrator elevation was cancelled or failed. Cannot proceed without Admin rights."
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         8Store (Re8Store Revival) Installer" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 2. Locate certificate
$cerPath = Join-Path $PSScriptRoot "Re8Store.cer"
if (-not (Test-Path $cerPath)) {
    # Check parent directory
    $cerPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Re8Store.cer"
}
if (-not (Test-Path $cerPath)) {
    # Recursive search
    $foundCer = Get-ChildItem -Path $PSScriptRoot -Filter "*.cer" -Recurse -File | Select-Object -First 1
    if ($foundCer) { $cerPath = $foundCer.FullName }
}

if (-not (Test-Path $cerPath)) {
    Write-Error "Certificate file 'Re8Store.cer' not found in $PSScriptRoot"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[1/2] Importing code-signing certificate into Local Machine stores..." -ForegroundColor Yellow
Write-Host "      Certificate: $cerPath" -ForegroundColor Gray

try {
    # .NET X509Store import
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cerPath)

    $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::Root, [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
    $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $rootStore.Add($cert)
    $rootStore.Close()

    $peopleStore = New-Object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::TrustedPeople, [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
    $peopleStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $peopleStore.Add($cert)
    $peopleStore.Close()

    # Also run certutil as fallback for older Windows environments
    & certutil.exe -addstore -f "Root" $cerPath | Out-Null
    & certutil.exe -addstore -f "TrustedPeople" $cerPath | Out-Null

    Write-Host "      [OK] Certificate successfully trusted (CN=Ibrahim)." -ForegroundColor Green
} catch {
    Write-Error "Failed to import certificate: $_"
    Read-Host "Press Enter to exit"
    exit 1
}

# 3. Locate AppX package
$appxPath = Join-Path $PSScriptRoot "Re8Store_Official.appx"
if (-not (Test-Path $appxPath)) {
    $appxPath = Join-Path $PSScriptRoot "update.appx"
}
if (-not (Test-Path $appxPath)) {
    $appxPath = Join-Path $PSScriptRoot "updates\update.appx"
}
if (-not (Test-Path $appxPath)) {
    $found = Get-ChildItem -Path $PSScriptRoot -Filter "*.appx" -Recurse -File | Select-Object -First 1
    if ($found) {
        $appxPath = $found.FullName
    }
}

if (-not (Test-Path $appxPath)) {
    Write-Error "No AppX package found in $PSScriptRoot"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "`n[2/2] Installing AppX package..." -ForegroundColor Yellow
Write-Host "      Package: $appxPath" -ForegroundColor Gray

try {
    Add-AppxPackage -Path $appxPath -ErrorAction Stop
    Write-Host "      [OK] AppX package installed successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to install AppX package: $_"
    Write-Host "`nTroubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Ensure Developer Mode / Sideloading is enabled on this system."
    Write-Host "2. If on Windows 8.1 / 10, run 'gpedit.msc' -> Computer Configuration -> Administrative Templates -> Windows Components -> App Package Deployment -> Allow all trusted apps to install -> Enabled."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " 8Store is now installed and ready to launch!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 2
