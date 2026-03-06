#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

$content = Get-Content $FilePath -Raw -Encoding UTF8

# Add getters right after State class declaration
# Regex to match State class declaration
$stateRegex = '(class _[A-Za-z0-9]+State extends State<[A-Za-z0-9]+>(?: with [A-Za-z0-9, ]+)? \{)'

if ($content -match $stateRegex) {
    if ($content -notmatch 'ThemeData get theme => Theme\.of\(context\);') {
        $content = $content -replace $stateRegex, "`$1`n  ThemeData get theme => Theme.of(context);`n  bool get isDark => theme.brightness == Brightness.dark;"
        Write-Host "Added theme getters to state class in $FilePath"
    } else {
        Write-Host "Theme getters already present in $FilePath"
    }
}

# Also handle StatelessWidgets if they have helper methods (though theme is usually in build scope there)
# But helper methods in StatelessWidgets usually take BuildContext context.
# If they don't, they are usually defined outside or as static, which is a different problem.

Set-Content -Path $FilePath -Value $content -Encoding UTF8 -NoNewline
