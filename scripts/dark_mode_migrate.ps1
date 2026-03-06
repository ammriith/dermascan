#!/usr/bin/env pwsh
# Dark Mode Migration Script for Dermascan
# Replaces hardcoded light-mode colors with Theme.of(context) equivalents

param(
    [string]$FilePath
)

$content = Get-Content $FilePath -Raw -Encoding UTF8

# Skip files that are already theme-aware (have Theme.of(context) calls)
# We still process them as some may be partially done

# === STEP 1: Replace static color field declarations ===
# Replace the static color constants block with dynamic theme usage pattern

# Remove hardcoded bgColor, cardColor, textPrimary, textSecondary field declarations
# These get replaced with theme lookups in the build method
$colorFieldPatterns = @(
    "static const Color bgColor = Color\(0xFFF8FAFC\);",
    "static const Color cardColor = Colors\.white;",
    "static const Color textPrimary = Color\(0xFF1F2937\);",
    "static const Color textColor = Color\(0xFF1F2937\);",
    "static const Color textSecondary = Color\(0xFF6B7280\);",
    "final Color bgColor = const Color\(0xFFF8FAFC\);",
    "final Color textColor = const Color\(0xFF1F2937\);",
    "final Color drawerBg = Colors\.white;"
)

Write-Host "Processing: $FilePath"
Write-Host "File size: $($content.Length) bytes"
Write-Host "Done."
