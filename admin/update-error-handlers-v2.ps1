#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates all admin stored procedures with improved SQLEXCEPTION error handling
#>

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Admin Procedures - Error Handler Update" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$proceduresDir = "admin_procedures"
$procedureFiles = Get-ChildItem -Path $proceduresDir -Filter "*.sql" | Where-Object { $_.Name -ne "01_admin_auth_login.sql" }

Write-Host "[INFO] Found $($procedureFiles.Count) procedures to update`n" -ForegroundColor Yellow

$updatedCount = 0

foreach ($file in $procedureFiles) {
    Write-Host "[PROCESSING] $($file.Name)..." -ForegroundColor White
    
    try {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $originalContent = $content
        
        # Step 1: Update SQLEXCEPTION handler
        # Find and replace the old pattern with improved version
        $pattern = "(?s)(DECLARE EXIT HANDLER FOR SQLEXCEPTION\s+BEGIN\s+)" +
                   "(?:SET v_end_time = NOW\(\);.*?)" +
                   "(GET DIAGNOSTICS CONDITION 1\s+v_error_message = MESSAGE_TEXT,\s+v_error_code = MYSQL_ERRNO;)" +
                   "(.*?)(INSERT INTO activity_log.*?ADMIN_.*?_ERROR'\);)" +
                   "(.*?)(SELECT\s+'fail' AS status,.*?'.*? failed due to system error' AS error_message;)" +
                   "(\s+END;)"
        
        if ($content -match $pattern) {
            # Replace with improved handler
            $replacement = @"
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
            INSERT INTO activity_log (log_type, message, created_by, start_time, end_time, execution_time, activity_type)
            VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'system', v_start_time, v_end_time, v_execution_time, 'PROCEDURE_ERROR');
        END;
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Unknown SQL exception occurred') AS error_message;
    END;
"@
            
            $content = $content -replace $pattern, $replacement
        }
        
        # Save if changed
        if ($content -ne $originalContent) {
            Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
            Write-Host "  ✓ Updated" -ForegroundColor Green
            $updatedCount++
        } else {
            Write-Host "  ⊘ No changes needed" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Successfully updated: $updatedCount procedures" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

if ($updatedCount -gt 0) {
    Write-Host "[NEXT STEP] Redeploy procedures:" -ForegroundColor Cyan
    Write-Host "            .\deploy-admin-system.ps1 -ProceduresOnly`n" -ForegroundColor White
}
