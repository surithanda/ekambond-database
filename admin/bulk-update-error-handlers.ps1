#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Bulk update all admin procedures with correct SQLEXCEPTION error handler
#>

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Bulk Error Handler Update" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$proceduresDir = "admin_procedures"

# List of procedures to update (excluding already updated ones)
$proceduresToUpdate = @(
    "06_admin_auth_confirm_reset_password.sql",
    "07_admin_users_create.sql",
    "08_admin_users_update.sql",
    "09_admin_users_list.sql",
    "10_admin_get_registrations.sql",
    "11_admin_get_profiles.sql",
    "12_admin_enable_disable_account.sql",
    "13_admin_update_verify_status.sql",
    "14_admin_get_total_payments.sql",
    "15_admin_get_partner_registrations.sql",
    "16_admin_approve_partner_registrations.sql",
    "17_admin_get_api_clients.sql",
    "18_admin_get_api_client_payments.sql",
    "admin_api_clients_create_v1.sql",
    "admin_registered_partner_delete_v1.sql",
    "admin_registered_partner_get.sql",
    "admin_registered_partner_update_v1.sql"
)

$updatedCount = 0
$errorCount = 0

foreach ($fileName in $proceduresToUpdate) {
    $filePath = Join-Path $proceduresDir $fileName
    
    if (-not (Test-Path $filePath)) {
        Write-Host "[SKIP] $fileName - File not found" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "[PROCESSING] $fileName..." -ForegroundColor White
    
    try {
        $content = Get-Content -Path $filePath -Raw -Encoding UTF8
        $originalContent = $content
        
        # Step 1: Add variables if they don't exist
        # Look for the pattern where error variables are declared
        if ($content -match "DECLARE v_error_code VARCHAR\(10\);\s+DECLARE v_error_message VARCHAR\(255\);") {
            # Check if v_mysql_errno and v_message_text are already there
            if ($content -notmatch "DECLARE v_mysql_errno INT;") {
                # Add them after v_error_message
                $content = $content -replace "(DECLARE v_error_message VARCHAR\(255\);)", "`$1`n    DECLARE v_mysql_errno INT;`n    DECLARE v_message_text TEXT;"
                Write-Host "  → Added variable declarations" -ForegroundColor Gray
            }
        }
        
        # Step 2: Update SQLEXCEPTION handler
        # Pattern to match the old handler
        $oldHandlerPattern = "(?s)(DECLARE EXIT HANDLER FOR SQLEXCEPTION\s+BEGIN\s+)" +
                            "GET DIAGNOSTICS CONDITION 1\s+" +
                            "v_error_message = MESSAGE_TEXT,\s+" +
                            "v_error_code = MYSQL_ERRNO;\s+" +
                            "SELECT\s+'fail' AS status,\s+" +
                            "'SQL Exception' AS error_type,\s+" +
                            "v_error_code AS error_code,\s+" +
                            "v_error_message AS error_message;\s+" +
                            "END;"
        
        # New handler replacement
        $newHandler = @"
DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_message_text = MESSAGE_TEXT,
            v_mysql_errno = MYSQL_ERRNO;
        
        INSERT INTO activity_log (log_type, message, activity_type)
        VALUES ('ERROR', COALESCE(v_message_text, 'Unknown SQL error'), 'PROCEDURE_ERROR');
        
        SELECT 
            'fail' AS status,
            'SQL Exception' AS error_type,
            CAST(COALESCE(v_mysql_errno, 48001) AS CHAR) AS error_code,
            COALESCE(v_message_text, 'Procedure execution failed') AS error_message;
    END;
"@
        
        if ($content -match $oldHandlerPattern) {
            $content = $content -replace $oldHandlerPattern, $newHandler
            Write-Host "  → Updated EXIT HANDLER" -ForegroundColor Gray
        }
        
        # Save if changed
        if ($content -ne $originalContent) {
            Set-Content -Path $filePath -Value $content -Encoding UTF8 -NoNewline
            Write-Host "  ✓ Updated successfully" -ForegroundColor Green
            $updatedCount++
        } else {
            Write-Host "  ⊘ No changes made" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
    
    Write-Host ""
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Successfully updated: $updatedCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red
Write-Host ""

if ($updatedCount -gt 0) {
    Write-Host "[NEXT STEP] Redeploy procedures:" -ForegroundColor Cyan
    Write-Host "            .\deploy-admin-system.ps1 -ProceduresOnly`n" -ForegroundColor White
}
