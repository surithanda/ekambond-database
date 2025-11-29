#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates all admin stored procedures with improved error handling
.DESCRIPTION
    This script updates the SQLEXCEPTION handler in all admin procedures to:
    1. Capture actual error details using GET DIAGNOSTICS
    2. Safely log errors with nested CONTINUE handler
    3. Return detailed error information instead of generic messages
#>

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Admin Procedures Error Handler Update" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$proceduresDir = "admin_procedures"
$procedureFiles = Get-ChildItem -Path $proceduresDir -Filter "*.sql" | Where-Object { $_.Name -ne "01_admin_auth_login.sql" }

Write-Host "[INFO] Found $($procedureFiles.Count) procedures to update (excluding 01_admin_auth_login.sql)`n" -ForegroundColor Yellow

$updatedCount = 0
$skippedCount = 0
$errorCount = 0

foreach ($file in $procedureFiles) {
    Write-Host "[PROCESSING] $($file.Name)..." -ForegroundColor White
    
    try {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        
        # Check if it already has the old error handler pattern
        if ($content -match "DECLARE EXIT HANDLER FOR SQLEXCEPTION") {
            Write-Host "  → Found SQLEXCEPTION handler" -ForegroundColor Gray
            
            # Pattern 1: Simple error handler without GET DIAGNOSTICS
            $oldPattern1 = [regex]::Escape("DECLARE EXIT HANDLER FOR SQLEXCEPTION") + 
                          "[\s\S]*?" + 
                          "BEGIN[\s\S]*?" +
                          "SELECT\s+'fail'[\s\S]*?" +
                          "'Authentication failed due to system error'[\s\S]*?" +
                          "END;"
            
            # New improved error handler
            $newHandler = @"
DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        DECLARE v_mysql_errno INT;
        DECLARE v_message_text TEXT;
        
        SET v_end_time = NOW();
        SET v_execution_time = TIMESTAMPDIFF(MICROSECOND, v_start_time, v_end_time);
        
        GET DIAGNOSTICS CONDITION 1
            v_message_text = MESSAGE_TEXT,
            v_mysql_errno = MYSQL_ERRNO;
        
        -- Try to log error, but don't fail if logging fails
        BEGIN
            DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;
            INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, ip_address, activity_type)
            VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'system', v_start_time, v_end_time, v_execution_time, NULL, 'PROCEDURE_ERROR');
        END;
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Unknown SQL exception occurred') AS error_message;
    END;
"@
            
            # Try to update
            $updatedContent = $content -replace $oldPattern1, $newHandler
            
            if ($updatedContent -ne $content) {
                Set-Content -Path $file.FullName -Value $updatedContent -Encoding UTF8 -NoNewline
                Write-Host "  ✓ Updated error handler" -ForegroundColor Green
                $updatedCount++
            } else {
                Write-Host "  ⊘ Pattern not matched, needs manual review" -ForegroundColor Yellow
                $skippedCount++
            }
        } else {
            Write-Host "  ⊘ No SQLEXCEPTION handler found, skipping" -ForegroundColor Yellow
            $skippedCount++
        }
        
    } catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
    
    Write-Host ""
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Update Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total procedures processed: $($procedureFiles.Count)" -ForegroundColor White
Write-Host "Successfully updated:       $updatedCount" -ForegroundColor Green
Write-Host "Skipped (needs manual):     $skippedCount" -ForegroundColor Yellow
Write-Host "Errors:                     $errorCount" -ForegroundColor Red
Write-Host ""

if ($updatedCount -gt 0) {
    Write-Host "[NOTE] Remember to redeploy procedures:" -ForegroundColor Cyan
    Write-Host "       .\deploy-admin-system.ps1 -ProceduresOnly" -ForegroundColor White
    Write-Host ""
}
