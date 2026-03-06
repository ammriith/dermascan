
function Fix-File {
    param([string]$path, [hashtable]$replacements)
    Write-Host "Processing $path..."
    if (-not (Test-Path $path)) {
        Write-Warning "File not found: $path"
        return
    }
    $content = [System.IO.File]::ReadAllText($path)
    $original = $content
    
    $keys = $replacements.Keys | Sort-Object -Property Length -Descending
    
    foreach ($target in $keys) {
        $replacement = $replacements[$target]
        $content = $content.Replace($target, $replacement)
    }
    
    if ($content -ne $original) {
        Write-Host "Saving changes to $path..."
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
    } else {
        Write-Host "No changes needed for $path."
    }
}

# 2. Patient Payments
Fix-File "lib/patient/patient_payments.dart" @{
    "icon: const Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20)," = "icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),"
    "style: const TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)," = "style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),"
    "unselectedLabelcolor: theme.colorScheme.onSurface.withValues(alpha: 0.6)," = "unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),"
    "class _PaymentGatewaySheetState extends State<_PaymentGatewaySheet> {" = "class _PaymentGatewaySheetState extends State<_PaymentGatewaySheet> {`r`n  ThemeData get theme => Theme.of(context);`r`n  bool get isDark => theme.brightness == Brightness.dark;"
}

# 3. View Appointment
Fix-File "lib/patient/view_appointment.dart" @{
    "icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface)," = "icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface),"
    "style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)," = "style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),"
    "style: const TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))," = "style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),"
    "color: cardColor," = "color: theme.cardColor,"
    "color: textSecondary" = "color: theme.colorScheme.onSurface.withValues(alpha: 0.6)"
    "color: textPrimary" = "color: theme.colorScheme.onSurface"
    "class _ViewAppointmentPageState extends State<ViewAppointmentPage> {" = "class _ViewAppointmentPageState extends State<ViewAppointmentPage> {`r`n  ThemeData get theme => Theme.of(context);`r`n  bool get isDark => theme.brightness == Brightness.dark;"
}

# 4. Patient Reminders
Fix-File "lib/patient/patient_reminders.dart" @{
    "icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface)," = "icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface),"
    "style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)," = "style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),"
    "style: const TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))," = "style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),"
    "style: const TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.5)," = "style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.5),"
    "style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)," = "style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),"
    "color: isOverdue ? redAccent : textPrimary," = "color: isOverdue ? redAccent : theme.colorScheme.onSurface,"
}

# 5. Patient Medical History
Fix-File "lib/patient/patient_medical_history.dart" @{
    "icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface)," = "icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface),"
    "style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)," = "style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),"
    "style: const TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))," = "style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),"
    "unselectedLabelcolor: theme.colorScheme.onSurface.withValues(alpha: 0.6)," = "unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),"
    "color: theme.cardColor," = "color: theme.cardColor,"
    "color: bgColor" = "color: theme.scaffoldBackgroundColor"
    "class _DetailedReportPageState extends State<DetailedReportPage> {" = "class _DetailedReportPageState extends State<DetailedReportPage> {`r`n  ThemeData get theme => Theme.of(context);`r`n  bool get isDark => theme.brightness == Brightness.dark;"
    "class _ComparisonPageState extends State<ComparisonPage> {" = "class _ComparisonPageState extends State<ComparisonPage> {`r`n  ThemeData get theme => Theme.of(context);`r`n  bool get isDark => theme.brightness == Brightness.dark;"
}

# 6. Patient Appointment
Fix-File "lib/patient/patient_appointment.dart" @{
    "style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)," = "style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),"
    "style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)," = "style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),"
    "style: const TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)," = "style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),"
    "color: textSecondary" = "color: theme.colorScheme.onSurface.withValues(alpha: 0.6)"
    "color: textPrimary" = "color: theme.colorScheme.onSurface"
    "color: cardColor" = "color: theme.cardColor"
}

# 7. View Users (Admin)
Fix-File "lib/admin/view_users.dart" @{
    "icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface)," = "icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface),"
    "style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)," = "style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),"
    "unselectedLabelcolor: theme.colorScheme.onSurface.withValues(alpha: 0.6)," = "unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),"
    "Text(`"Current User`", style: const TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))," = "Text(`"Current User`", style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),"
    "color: bgColor," = "color: theme.scaffoldBackgroundColor,"
}

# 8. View Patients (Admin)
Fix-File "lib/admin/view_patients.dart" @{
    "icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface)," = "icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.colorScheme.onSurface),"
    "color: bgColor," = "color: theme.scaffoldBackgroundColor,"
    "class PatientDetailsPage extends StatefulWidget {" = "class PatientDetailsPage extends StatefulWidget {`r`n  ThemeData get theme => Theme.of(context);`r`n  bool get isDark => theme.brightness == Brightness.dark;"
    "class PatientRecordsPage extends StatefulWidget {" = "class PatientRecordsPage extends StatefulWidget {`r`n  ThemeData get theme => Theme.of(context);`r`n  bool get isDark => theme.brightness == Brightness.dark;"
}

# 9. Add Doctor (Admin)
Fix-File "lib/admin/add_doctor.dart" @{
    "color: textPrimary" = "color: theme.colorScheme.onSurface"
    "color: textSecondary" = "color: theme.colorScheme.onSurface.withValues(alpha: 0.6)"
    "color: primaryColor" = "color: Color(0xFF4FD1C5)"
}

# 10. Admin Dashboard
Fix-File "lib/admin/admin_dashboard.dart" @{
    "color: textPrimary" = "color: theme.colorScheme.onSurface"
    "color: textSecondary" = "color: theme.colorScheme.onSurface.withValues(alpha: 0.6)"
    "void _handleUnauthorized() async {" = "ThemeData get theme => Theme.of(context);`r`n  bool get isDark => theme.brightness == Brightness.dark;`r`n`r`n  void _handleUnauthorized() async {"
}
