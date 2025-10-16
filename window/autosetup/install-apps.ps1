# AutoSetup.ps1
# Chạy với quyền Admin
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# ---- Cấu hình ----
$softwareDir = Join-Path $env:TEMP "AutoSetupInstallers"
New-Item -Path $softwareDir -ItemType Directory -Force | Out-Null

# Danh sách ứng dụng và thông tin tải/cài
$apps = @(
    @{
        Name = "WinRAR"
        Url  = "https://www.rarlab.com/rar/winrar-x64-611br.exe"   # THAY bằng link chính thức mới nhất
        File = "WinRAR-x64.exe"
        Args = "/S"   # silent switch cho WinRAR
    },
    @{
        Name = "Zalo"
        Url  = "https://pc.zalo.me/download.ZaloSetup.exe"        # THAY bằng link chính thức
        File = "ZaloSetup.exe"
        Args = "/S"   # nếu không hỗ trợ /S thì test hoặc bỏ
    },
    @{
        Name = "GoogleChrome"
        Url  = "https://dl.google.com/tag/s/appguid%3D%7B8A69D345-..."  # ví dụ; thay link MSI/EXE chính thức
        File = "ChromeSetup.exe"
        Args = "/silent /install"  # tuỳ installer; dùng MSI nếu có: msiexec /i file.msi /qn
    }
)

# ---- Hàm download với retry ----
function Download-File {
    param([string]$Url, [string]$OutPath, [int]$Retries = 3)
    for ($i=1; $i -le $Retries; $i++) {
        try {
            Write-Host "Downloading $Url (attempt $i) ..."
            Invoke-WebRequest -Uri $Url -OutFile $OutPath -UseBasicParsing -TimeoutSec 120
            Write-Host "Downloaded to $OutPath"
            return $true
        } catch {
            Write-Warning "Download failed: $_"
            Start-Sleep -Seconds (3 * $i)
        }
    }
    return $false
}

# ---- Hàm chạy installer ----
function Run-Installer {
    param([string]$Path, [string]$Args)
    if (-not (Test-Path $Path)) {
        Write-Warning "Installer không tồn tại: $Path"
        return $false
    }
    Write-Host "Running installer: $Path $Args"
    try {
        $proc = Start-Process -FilePath $Path -ArgumentList $Args -Wait -PassThru -WindowStyle Hidden
        Write-Host "$($proc.ExitCode) : $Path completed"
        return $true
    } catch {
        Write-Warning "Lỗi chạy installer: $_"
        return $false
    }
}

# ---- Thực hiện download + cài cho từng app ----
foreach ($app in $apps) {
    $out = Join-Path $softwareDir $app.File
    Write-Host "`n=== $($app.Name) ===" -ForegroundColor Cyan
    $ok = Download-File -Url $app.Url -OutPath $out
    if ($ok) {
        # Một số installer MSI nên chạy với msiexec
        if ($out.ToLower().EndsWith(".msi")) {
            $msiArgs = "/i `"$out`" /qn /norestart"
            Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait
        } else {
            Run-Installer -Path $out -Args $app.Args
        }
    } else {
        Write-Warning "Bỏ qua cài $($app.Name) vì không tải được."
    }
}

# ---- Tùy chọn: cài thêm bằng winget nếu muốn (dự phòng) ----
try {
    Write-Host "`nThử cài bằng winget (nếu có): Chrome, VSCode"
    winget install -e --id Google.Chrome --accept-source-agreements --accept-package-agreements -h
    winget install -e --id Microsoft.VisualStudioCode --accept-source-agreements --accept-package-agreements -h
} catch {
    Write-Warning "Winget không hoạt động hoặc không cần thiết."
}

# ---- Join domain (cuối cùng) ----
# LƯU Ý: yêu cầu chạy script với quyền admin, domain reachable

# $doJoin = Read-Host "Bạn có muốn join domain không? (Y/N)"
# if ($doJoin -match '^[Yy]') {
#     $domain = Read-Host "Nhập domain (ví dụ CORP)"
#     $credential = Get-Credential -Message "Nhập domain admin (ví dụ $domain\\admin)"
#     try {
#         Add-Computer -DomainName $domain -Credential $credential -Force -ErrorAction Stop
#         Write-Host "Join domain thành công. Restarting..." -ForegroundColor Green
#         Start-Sleep -Seconds 4
#         Restart-Computer -Force
#     } catch {
#         Write-Warning "Join domain thất bại: $_"
#     }
# } else {
#     Write-Host "Bỏ qua join domain."
# }

Write-Host "`nTất cả hoàn tất." -ForegroundColor Green
Pause
