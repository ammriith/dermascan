#!/usr/bin/env pwsh
# Dark Mode Migration Script - Replaces hardcoded light-mode colors with theme lookups
# Usage: .\apply_dark_mode.ps1 -FilePath "path\to\file.dart"

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    [switch]$DryRun
)

if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

$content = Get-Content $FilePath -Raw -Encoding UTF8
$original = $content

# ===== STEP 1: Add theme/isDark to build methods =====
# Find build methods that use hardcoded colors and add theme lookups

# Remove static color field declarations (bgColor, cardColor, textPrimary, textSecondary)
$content = $content -replace "  static const Color bgColor = Color\(0xFFF8FAFC\);\r?\n", ""
$content = $content -replace "  static const Color cardColor = Colors\.white;\r?\n", ""
$content = $content -replace "  static const Color textPrimary = Color\(0xFF1F2937\);\r?\n", ""
$content = $content -replace "  static const Color textColor = Color\(0xFF1F2937\);\r?\n", ""
$content = $content -replace "  static const Color textSecondary = Color\(0xFF6B7280\);\r?\n", ""
$content = $content -replace "  static const Color bgColor = Color\(0xFFF7FAFC\);\r?\n", ""

# Remove non-static versions too
$content = $content -replace "  final Color bgColor = const Color\(0xFFF8FAFC\);\s*\r?\n", ""
$content = $content -replace "  final Color textColor = const Color\(0xFF1F2937\);\s*\r?\n", ""
$content = $content -replace "  final Color drawerBg = Colors\.white;\r?\n", ""

# ===== STEP 2: Add theme variables at start of build() =====
# Only if not already present
if ($content -notmatch 'final theme = Theme\.of\(context\)') {
    # Add theme variables right after build method opening
    $content = $content -replace '(Widget build\(BuildContext context\) \{)', "`$1`n    final theme = Theme.of(context);`n    final isDark = theme.brightness == Brightness.dark;"
}

# ===== STEP 3: Replace color usages =====
# Scaffold background
$content = $content -replace 'backgroundColor: bgColor,', 'backgroundColor: theme.scaffoldBackgroundColor,'

# Card colors
$content = $content -replace '\bcolor: cardColor\b', 'color: theme.cardColor'
$content = $content -replace 'backgroundColor: cardColor,', 'backgroundColor: theme.cardColor,'

# Text colors - textPrimary  
$content = $content -replace 'color: textPrimary\b', 'color: theme.colorScheme.onSurface'
$content = $content -replace "const TextStyle\(([^)]*?)color: textPrimary", "TextStyle(`$1color: theme.colorScheme.onSurface"

# Text colors - textSecondary
$content = $content -replace 'color: textSecondary\b', 'color: theme.colorScheme.onSurface.withValues(alpha: 0.6)'
$content = $content -replace "const TextStyle\(([^)]*?)color: textSecondary", "TextStyle(`$1color: theme.colorScheme.onSurface.withValues(alpha: 0.6)"

# Text colors - textColor (as used in some files)
$content = $content -replace 'color: textColor\b', 'color: theme.colorScheme.onSurface'

# AppBar backgrounds
$content = $content -replace 'backgroundColor: Colors\.white,(\s*)(elevation: 0)', 'backgroundColor: theme.cardColor,$1$2'

# Grey shade borders
$content = $content -replace 'color: Colors\.grey\.shade200\)', 'color: theme.dividerColor)'
$content = $content -replace 'color: Colors\.grey\.shade100\)', 'color: theme.dividerColor)'
$content = $content -replace 'Border\.all\(color: Colors\.grey\.shade200', 'Border.all(color: theme.dividerColor'
$content = $content -replace 'Border\.all\(color: Colors\.grey\.shade100', 'Border.all(color: theme.dividerColor'

# Shadow colors - make them adaptive
$content = $content -replace 'Colors\.black\.withOpacity\(0\.04\)', 'Colors.black.withValues(alpha: isDark ? 0.15 : 0.04)'
$content = $content -replace "Colors\.black\.withValues\(alpha: 0\.04\)", "Colors.black.withValues(alpha: isDark ? 0.15 : 0.04)"

# Grey text colors
$content = $content -replace 'color: Colors\.grey\.shade600\)', 'color: theme.colorScheme.onSurface.withValues(alpha: 0.6))'
$content = $content -replace 'color: Colors\.grey\.shade500\)', 'color: theme.colorScheme.onSurface.withValues(alpha: 0.5))'
$content = $content -replace 'color: Colors\.grey\.shade400\)', 'color: theme.colorScheme.onSurface.withValues(alpha: 0.4))'
$content = $content -replace 'color: Colors\.grey\.shade300\)', 'color: theme.colorScheme.onSurface.withValues(alpha: 0.3))'

# Grey icon colors
$content = $content -replace 'color: Colors\.grey\[600\]', 'color: theme.colorScheme.onSurface.withValues(alpha: 0.6)'

# Card color for containers
$content = $content -replace 'color: Colors\.white\b,(\s*borderRadius)', 'color: theme.cardColor,$1'
$content = $content -replace "color: Colors\.white,(\s*)(child:)", "color: theme.cardColor,`$1`$2"

# Bottom sheet backgrounds
$content = $content -replace 'color: Colors\.white,(\s*borderRadius: const BorderRadius\.vertical)', 'color: theme.cardColor,$1'

# Drawer background
$content = $content -replace 'backgroundColor: drawerBg,', 'backgroundColor: theme.cardColor,'

# Fix double 'const' issues that might arise from removing const from TextStyle
$content = $content -replace 'const const ', 'const '

# Fix any broken "const TextStyle" that now has dynamic values
# TextStyle with theme lookups cannot be const
$content = $content -replace 'const TextStyle\(([^)]*?)theme\.', 'TextStyle($1theme.'

if ($DryRun) {
    Write-Host "=== DRY RUN - Changes for $FilePath ==="
    if ($content -eq $original) {
        Write-Host "No changes needed."
    } else {
        Write-Host "Changes would be applied."
    }
} else {
    if ($content -ne $original) {
        Set-Content -Path $FilePath -Value $content -Encoding UTF8 -NoNewline
        Write-Host "Updated: $FilePath"
    } else {
        Write-Host "No changes needed: $FilePath"
    }
}
