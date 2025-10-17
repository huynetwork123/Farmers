# install_apps.ps1
Write-Host "Dang cai dat cac ung dung co ban..." -ForegroundColor Cyan

# Danh sach ung dung muon cai
$apps = @(
    "Google.Chrome",
    "WinRAR",
    "Notepad++.Notepad++",
    "Microsoft.VisualStudioCode",
    "7zip.7zip",
    "VideoLAN.VLC",
    "Unikey",
    "ZaloPC.Zalo",
    "Zoom.Zoom",
    "SlackTechnologies.Slack"
)

foreach ($app in $apps) {
    Write-Host "`nCai dat: $app" -ForegroundColor Yellow
    try {
        winget install --id=$app --silent --accept-package-agreements --accept-source-agreements -e
    } catch {
        Write-Host "Loi khi cai dat $app" -ForegroundColor Red
    }
}

Write-Host "`nHoan tat cai dat tat ca phan mem!" -ForegroundColor Green
pause
