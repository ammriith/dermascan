
$files = Get-ChildItem -Recurse -Filter *.dart
foreach ($file in $files) {
    Write-Host "Fixing $($file.FullName)..."
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $original = $content
    
    # 1. Remove invalid const
    # We use a regex that looks for const followed by a widget and theme inside
    $content = $content -replace 'const\s+Icon\((?=.*theme)', 'Icon('
    $content = $content -replace 'const\s+TextStyle\((?=.*theme)', 'TextStyle('
    $content = $content -replace 'const\s+Container\((?=.*theme)', 'Container('
    $content = $content -replace 'const\s+BoxDecoration\((?=.*theme)', 'BoxDecoration('
    $content = $content -replace 'const\s+Divider\((?=.*theme)', 'Divider('
    
    # 2. Fix typos
    $content = $content -replace 'unselectedLabelcolor:', 'unselectedLabelColor:'
    
    # 3. Replace missing color variables with theme lookups
    # Only if 'theme' is available in the content (likely a State class)
    if ($content -contains "ThemeData get theme") {
        $content = $content -replace '(?<!theme\.)textPrimary(?!\w)', 'theme.colorScheme.onSurface'
        $content = $content -replace '(?<!theme\.)textSecondary(?!\w)', 'theme.colorScheme.onSurface.withValues(alpha: 0.6)'
        $content = $content -replace '(?<!theme\.)cardColor(?!\w)', 'theme.cardColor'
        $content = $content -replace '(?<!theme\.)bgColor(?!\w)', 'theme.scaffoldBackgroundColor'
    }

    # 4. Add theme getters to common state classes if missing
    if ($content -match 'class\s+_\w+State\s+extends\s+State<[^>]+>\s+\{' -and $content -notmatch 'ThemeData\s+get\s+theme') {
        $content = $content -replace '(class\s+_\w+State\s+extends\s+State<[^>]+>\s+\{)', "`$1`r`n  ThemeData get theme => Theme.of(context);`r`n  bool get isDark => theme.brightness == Brightness.dark;"
    }

    if ($content -ne $original) {
        Write-Host "Updating $($file.FullName)"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
    }
}
