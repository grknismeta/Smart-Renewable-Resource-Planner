# SRRP — Gece otomatik veri cekme (2026-05-21)
# ============================================================
# .bat yerine .ps1 — Windows .bat CRLF satir sonu gerektiriyor,
# editor LF yaziyordu ve satirlar bozuluyordu. PowerShell LF
# toleransli + UTF-8 sorunsuz.
#
# Scheduled task bunu cagirir:
#   powershell.exe -ExecutionPolicy Bypass -File run_overnight_fetch.ps1
#
# Her script (A/B/C) 4 kez calistirilir — resume sayesinde her
# gecis kalan ilceleri toplar. Calistirmalar arasi 3 dk bekleme.
# ============================================================

$ErrorActionPreference = "Continue"
$repo = "C:\Projelerim\smart_renewable_resource_planner"
$log  = "$repo\colab\overnight_fetch.log"
$py   = "$repo\backend\venv\Scripts\python.exe"

"=== SRRP Overnight Fetch ===" | Out-File -FilePath $log -Encoding utf8
"Baslangic: $(Get-Date)"        | Add-Content -Path $log -Encoding utf8

# A / B / C scriptleri — her biri 4 gecis, gecis arasi 180 sn
$scripts = @("A_open_meteo_hourly.py", "B_open_meteo_daily.py", "C_open_meteo_flood.py")
foreach ($script in $scripts) {
    "" | Add-Content -Path $log -Encoding utf8
    "--- $script ---" | Add-Content -Path $log -Encoding utf8
    for ($i = 1; $i -le 4; $i++) {
        "[gecis $i] $(Get-Date -Format 'HH:mm:ss')" | Add-Content -Path $log -Encoding utf8
        Set-Location "$repo\colab"
        & $py -X utf8 "$repo\colab\$script" *>> $log
        Start-Sleep -Seconds 180
    }
}

# DB import
"" | Add-Content -Path $log -Encoding utf8
"--- DB Import ---" | Add-Content -Path $log -Encoding utf8
Set-Location "$repo\backend"
& $py -X utf8 "$repo\backend\scripts\import_colab_csvs.py" *>> $log

"" | Add-Content -Path $log -Encoding utf8
"=== TAMAMLANDI $(Get-Date) ===" | Add-Content -Path $log -Encoding utf8
