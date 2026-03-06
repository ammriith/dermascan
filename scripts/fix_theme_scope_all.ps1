$projectDir = "c:\Users\Amirth\Documents\dermascan"
$filesToFix = @(
    "lib\admin\add_doctor.dart",
    "lib\patient\view_appointment.dart",
    "lib\patient\patient_dashboard.dart",
    "lib\patient\patient_medical_history.dart",
    "lib\patient\patient_payments.dart",
    "lib\patient\patient_appointment.dart",
    "lib\patient\patient_register.dart",
    "lib\patient\patient_reminders.dart",
    "lib\admin\admin_dashboard.dart",
    "lib\admin\appointments_page.dart",
    "lib\admin\change_password_page.dart",
    "lib\admin\settings_page.dart",
    "lib\admin\skin_scanner.dart",
    "lib\admin\staff_book_appointment.dart",
    "lib\admin\staff_edit_profile.dart",
    "lib\admin\staff_register_patient.dart",
    "lib\admin\view_doctors.dart",
    "lib\admin\view_patients.dart",
    "lib\admin\view_revenue.dart",
    "lib\admin\view_today_appointments.dart",
    "lib\admin\view_users.dart",
    "lib\doctor\doctor_dashboard.dart",
    "lib\doctor\doctor_edit_profile.dart",
    "lib\doctor\doctor_slots_page.dart",
    "lib\doctor\patient_reports.dart",
    "lib\doctor\view_feedbacks_page.dart"
)

$replacements = @{
    "\btextSecondary\b" = "theme.colorScheme.onSurface.withValues(alpha: 0.6)"
    "\btextPrimary\b" = "theme.colorScheme.onSurface"
    "\bbgColor\b" = "theme.scaffoldBackgroundColor"
    "\btextColor\b" = "theme.colorScheme.onSurface"
    "\bcardColor\b" = "theme.cardColor"
    "const\s+Icon\(([^)]*?theme\.[^)]*?)\)" = "Icon(`$1)"
    "const\s+Text\(([^)]*?theme\.[^)]*?)\)" = "Text(`$1)"
    "const\s+TextStyle\(([^)]*?theme\.[^)]*?)\)" = "TextStyle(`$1)"
    "const\s+BoxDecoration\(([^)]*?theme\.[^)]*?)\)" = "BoxDecoration(`$1)"
    "const\s+BorderSide\(([^)]*?theme\.[^)]*?)\)" = "BorderSide(`$1)"
    "theme\.theme\." = "theme."
}

foreach ($file in $filesToFix) {
    $filePath = "$projectDir\$file"
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw
        $modified = $false
        
        foreach ($key in $replacements.Keys) {
            if ($content -match $key) {
                $content = [regex]::Replace($content, $key, $replacements[$key])
                $modified = $true
            }
        }
        
        $oldContent = $content
        $content = [regex]::Replace($content, 'const\s+(Text|Icon|TextStyle|BoxDecoration|BorderSide|Padding|Container|SizedBox|Expanded)\s*\(([^)]*?theme\.[^)]*?)\)', '$1($2)')
        if ($oldContent -ne $content) { $modified = $true }
        
        if ($modified) {
            Write-Host "Modifying $filePath"
            Set-Content $filePath $content -NoNewline
        }
    }
}
