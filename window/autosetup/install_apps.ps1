# =============================
# 🚀 Auto Installer Script
# =============================
# Yêu cầu: chạy bằng quyền Admin

# --- Tạo thư mục tải ---
$downloadDir = "$env:USERPROFILE\Downloads\AutoInstalls"
New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null

# --- Link tải chính thức ---
$chromeUrl = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
$zaloUrl   = "https://zalo.me/download/zalo-pc?utm=90000"

# --- File lưu ---
$chromeFile = Join-Path $downloadDir "chrome_installer.exe"
$zaloFile   = Join-Path $downloadDir "zalo_pc.exe"


# ==========================================================
# ⚙️  HÀM 1 - Kiểm tra ứng dụng đã cài hay chưa
# ==========================================================
function IsAppInstalled {
    param([string]$AppName)

    Write-Host "🔍 Kiểm tra ứng dụng: $AppName..."

    # Kiểm tra registry uninstall key (Windows Apps)
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($key in $keys) {
        $apps = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -and $_.DisplayName -match $AppName }
        if ($apps) {
            Write-Host "✅ Đã tìm thấy: $($apps.DisplayName)"
            return $true
        }
    }

    Write-Host "❌ Ứng dụng chưa được cài."
    return $false
}


# ==========================================================
# ⚙️  HÀM 2 - Tải file (có credential)
# ==========================================================
function Download($url, $out, [System.Management.Automation.PSCredential]$Credential = $null) {
    Write-Host "⬇️ Tải $url ..."
    try {
        if ($Credential -ne $null) {
            Invoke-WebRequest -Uri $url -OutFile $out -Credential $Credential -UseBasicParsing -ErrorAction Stop
        } else {
            Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -ErrorAction Stop
        }
        Write-Host "→ Đã tải xong: $out"
        return $true
    } catch {
        Write-Warning "⚠️ Lỗi khi tải $url : $($_.Exception.Message)"
        return $false
    }
}


# ==========================================================
# ⚙️  HÀM 3 - Cài đặt im lặng (silent install)
# ==========================================================
function InstallSilent($file) {
    if (-not (Test-Path $file)) {
        Write-Warning "⚠️ File không tồn tại: $file"
        return $false
    }

    Write-Host "🛠️  Bắt đầu cài đặt: $file"
    $args = @("/S","/silent","/verysilent","--silent","/quiet","/q")

    foreach ($a in $args) {
        try {
            $p = Start-Process -FilePath $file -ArgumentList $a -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            if ($p.ExitCode -eq 0 -or $p.HasExited) {
                Write-Host "✅ Cài đặt thành công với tham số $a"
                return $true
            }
        } catch {}
    }

    Write-Warning "⚠️ Không cài được im lặng, cần cài thủ công: $file"
    return $false
}


# ==========================================================
# ⚙️  HÀM 4 - Đảm bảo ứng dụng đã được cài (chính logic chính)
# ==========================================================
function EnsureAppInstalled {
    param(
        [Parameter(Mandatory=$true)][string]$AppName,
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$InstallerPath
    )

    Write-Host "`n==============================="
    Write-Host "🔧 Kiểm tra & cài đặt: $AppName"
    Write-Host "==============================="

    # B1. Kiểm tra đã cài chưa
    if (IsAppInstalled $AppName) {
        Write-Host "➡️  Bỏ qua, $AppName đã được cài."
        return
    }

    # B2. Kiểm tra có file cài chưa
    if (-not (Test-Path $InstallerPath)) {
        Write-Host "📦 Không tìm thấy file cài, tiến hành tải..."
        $downloadOk = Download -url $Url -out $InstallerPath
        if (-not $downloadOk) {
            Write-Warning "⚠️ Tải thất bại cho $AppName!"
            return
        }
    } else {
        Write-Host "✅ Đã có file cài: $InstallerPath"
    }

    # B3. Thực hiện cài đặt
    InstallSilent $InstallerPath

    Write-Host "🎯 Hoàn tất xử lý $AppName.`n"
}


# ==========================================================
# ⚙️  HÀM 5 - Cài đặt từ Remote nếu cần
# (giữ nguyên từ script cũ, rút gọn phần chính)
# ==========================================================
function InstallFromRemote {
    param(
        [Parameter(Mandatory=$true)][string]$RemotePath,
        [string]$Username,
        [string]$Password,
        [System.Management.Automation.PSCredential]$Credential,
        [string]$LocalTemp = $downloadDir
    )

    if (-not (Test-Path $LocalTemp)) { New-Item -Path $LocalTemp -ItemType Directory -Force | Out-Null }

    if ($Credential -eq $null -and $Username) {
        if (-not $Password) {
            $securePwd = Read-Host -AsSecureString "Nhập mật khẩu cho $Username"
        } else {
            $securePwd = ConvertTo-SecureString -String $Password -AsPlainText -Force
        }
        $Credential = New-Object System.Management.Automation.PSCredential ($Username, $securePwd)
    }

    $fileName = [System.IO.Path]::GetFileName($RemotePath)
    if (-not $fileName) { Write-Warning "Không xác định được tên file từ RemotePath."; return $false }
    $localFile = Join-Path $LocalTemp $fileName

    if ($RemotePath -match '^https?://') {
        Write-Host "🌐 Tải file từ URL remote..."
        if (Download -url $RemotePath -out $localFile -Credential $Credential) {
            InstallSilent $localFile
        }
    } elseif ($RemotePath -match '^\\\\') {
        Write-Host "🔗 Kết nối share mạng SMB..."
        $uncParts = $RemotePath -split '\\' | Where-Object { $_ -ne '' }
        if ($uncParts.Count -lt 2) { Write-Warning "Đường dẫn UNC không hợp lệ."; return $false }
        $server = $uncParts[0]; $share = $uncParts[1]; $root = "\\$server\$share"
        $driveName = "TMP" + ([System.Guid]::NewGuid().ToString("N")).Substring(0,6)
        try {
            if ($Credential -ne $null) {
                New-PSDrive -Name $driveName -PSProvider FileSystem -Root $root -Credential $Credential -ErrorAction Stop | Out-Null
            } else {
                New-PSDrive -Name $driveName -PSProvider FileSystem -Root $root -ErrorAction Stop | Out-Null
            }
            $relative = $RemotePath.Substring($root.Length).TrimStart('\')
            $mappedPath = Join-Path ("$($driveName):\") $relative
            if (Test-Path $mappedPath) {
                Copy-Item -Path $mappedPath -Destination $localFile -Force -ErrorAction Stop
                InstallSilent $localFile
            } else {
                Write-Warning "Không tìm thấy file: $mappedPath"
            }
        } finally {
            try { Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
}

#fast download using HttpClient
function DownloadFast($url, $outFile) {
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $true
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36")

    Write-Host "⏬ Đang tải nhanh từ: $url"
    $response = $client.GetAsync($url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
    $stream = $response.Content.ReadAsStreamAsync().Result
    $fileStream = [System.IO.File]::Create($outFile)
    $stream.CopyTo($fileStream)
    $fileStream.Close()
    $client.Dispose()
    Write-Host "✅ Tải xong: $outFile"
}

function InstallFromRemoteFolder {
    param(
        [Parameter(Mandatory = $true)][string]$RemoteFolder,   # Thư mục UNC: \\server\share\SAP
        [string]$Installer = "setup.exe",                      # Tên file cài đặt chính
        [string]$Username,
        [string]$Password,
        [System.Management.Automation.PSCredential]$Credential,
        [string]$LocalBase = "$env:USERPROFILE\Downloads\AutoInstalls"
    )

    # --- Chuẩn bị thư mục tạm ---
    if (-not (Test-Path $LocalBase)) { New-Item -Path $LocalBase -ItemType Directory -Force | Out-Null }
    $folderName = [System.IO.Path]::GetFileName($RemoteFolder.TrimEnd('\'))
    $LocalTemp = Join-Path $LocalBase ("TMP_" + $folderName + "_" + (Get-Random))
    New-Item -Path $LocalTemp -ItemType Directory -Force | Out-Null

    Write-Host "📁 Copy toàn bộ thư mục từ $RemoteFolder → $LocalTemp ..."

    # --- Chuẩn bị credential nếu có ---
    if ($Credential -eq $null -and $Username) {
        $securePwd = if ($Password) {
            ConvertTo-SecureString -String $Password -AsPlainText -Force
        } else {
            Read-Host -AsSecureString "Nhập mật khẩu cho $Username"
        }
        $Credential = New-Object System.Management.Automation.PSCredential ($Username, $securePwd)
    }

    # --- Kết nối & copy ---
    $driveName = "TMP" + ([System.Guid]::NewGuid().ToString("N")).Substring(0,6)
    try {
        $root = ($RemoteFolder -split '\\', 4)[0..2] -join '\'
        if ($Credential) {
            New-PSDrive -Name $driveName -PSProvider FileSystem -Root $root -Credential $Credential -ErrorAction Stop | Out-Null
        } else {
            New-PSDrive -Name $driveName -PSProvider FileSystem -Root $root -ErrorAction Stop | Out-Null
        }

        $relativePath = $RemoteFolder.Substring($root.Length).TrimStart('\')
        $mappedPath = if ($relativePath) { "$($driveName):\$relativePath" } else { "$($driveName):\" }
        
        Copy-Item -Path $mappedPath -Destination $LocalTemp -Recurse -Force -ErrorAction Stop
        Write-Host "✅ Đã copy xong bộ cài."

        # --- Chạy cài đặt ---
        $installerPath = Join-Path $LocalTemp $Installer
        if (Test-Path $installerPath) {
            Write-Host "🚀 Đang cài đặt: $installerPath ..."
            Start-Process -FilePath $installerPath -Verb open -Wait
            Write-Host "✅ Cài đặt hoàn tất."
        } else {
            Write-Warning "Không tìm thấy file cài: $installerPath"
        }

    } catch {
        Write-Error "❌ Lỗi khi cài đặt từ $RemoteFolder $_"
    } finally {
        try { Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue } catch {}
    }

    # --- Dọn dẹp ---
    try {
        Write-Host "🧹 Xóa thư mục tạm: $LocalTemp"
        Remove-Item -Path $LocalTemp -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Không thể xóa thư mục tạm: $LocalTemp"
    }
}

#InstallFromRemoteFolder -RemoteFolder "\\server\share\SAP" -Installer "setup.exe"



# ==========================================================
# 🚀 Thực thi chính
# ==========================================================
#EnsureAppInstalled -AppName "Google Chrome" -Url $chromeUrl -InstallerPath $chromeFile
#EnsureAppInstalled -AppName "Zalo" -Url $zaloUrl -InstallerPath $zaloFile

# --- Ví dụ sử dụng ---
# 1) HTTP basic auth:
$cred = Get-Credential             # nhập username/password trong hộp thoại
InstallFromRemote -RemotePath "\\10.104.13.240\temp\ZaloSetup-25.8.3.exe" -Credential $cred

# 2) UNC share (nhập user/pass):
# InstallFromRemote -RemotePath "\\fileserver\share\tools\app.exe" -Username "DOMAIN\user"

# 3) UNC share (truyền password plain - KHÔNG KHUYẾN KHÍCH):
# InstallFromRemote -RemotePath "\\fileserver\share\tools\app.exe" -Username "DOMAIN\user" -Password "P@ssw0rd"

Write-Host "`n🎉 Toàn bộ quá trình đã hoàn tất!"
