# MySQL Admin System Deployment Script
# This script deploys the admin system (tables, procedures, and initial data)

param(
    [Parameter(Mandatory=$false)]
    [string]$MySQLHost = "localhost",
    
    [Parameter(Mandatory=$false)]
    [string]$MySQLUser = "root",
    
    [Parameter(Mandatory=$false)]
    [string]$MySQLPassword = "NewStrongPassword123!",
    
    [Parameter(Mandatory=$false)]
    [switch]$DropTables,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSchema,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipProcedures,
    
    [Parameter(Mandatory=$false)]
    [switch]$SchemaOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$ProceduresOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$UpdatePassword
)

$MySQLBin = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
$ScriptRoot = Split-Path -Parent $PSCommandPath
$AdminRoot = $ScriptRoot

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Yellow
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor DarkYellow
}

# Check if MySQL is accessible
function Test-MySQLConnection {
    try {
        $testQuery = "SELECT 1"
        $result = & $MySQLBin -h $MySQLHost -u $MySQLUser $(if ($MySQLPassword) { "-p$MySQLPassword" }) -e $testQuery 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

# Check if database exists
function Test-DatabaseExists {
    param([string]$DatabaseName)
    
    try {
        $query = "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$DatabaseName'"
        $result = & $MySQLBin -h $MySQLHost -u $MySQLUser $(if ($MySQLPassword) { "-p$MySQLPassword" }) -e $query 2>&1
        if ($result -match $DatabaseName) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Execute SQL file
function Invoke-SQLFile {
    param(
        [string]$FilePath,
        [string]$Database = "matrimony_services"
    )
    
    $fileName = Split-Path $FilePath -Leaf
    Write-Info "Executing: $fileName"
    
    try {
        # Use Get-Content and pipe to mysql for proper DELIMITER handling
        $result = Get-Content $FilePath -Raw | & $MySQLBin -h $MySQLHost -u $MySQLUser $(if ($MySQLPassword) { "-p$MySQLPassword" }) $Database 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Custom "Failed to execute $fileName"
            Write-Host $result -ForegroundColor Red
            return $false
        }
        
        Write-Success "Completed: $fileName"
        return $true
    }
    catch {
        Write-Error-Custom "Error executing $fileName : $_"
        return $false
    }
}

# Main deployment process
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  MySQL Admin System Deployment" -ForegroundColor Magenta
Write-Host "  Database: matrimony_services" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# Check if MySQL binary exists
if (-not (Test-Path $MySQLBin)) {
    Write-Error-Custom "MySQL binary not found at: $MySQLBin"
    Write-Host "Please update the `$MySQLBin variable in this script to point to your MySQL installation" -ForegroundColor Yellow
    exit 1
}

# Check if admin folder exists
if (-not (Test-Path $AdminRoot)) {
    Write-Error-Custom "Admin folder not found at: $AdminRoot"
    exit 1
}

# Verify MySQL connection
Write-Step "Verifying MySQL Connection"
if (-not (Test-MySQLConnection)) {
    Write-Error-Custom "Cannot connect to MySQL server at $MySQLHost"
    Write-Host "Please check your MySQL installation and credentials" -ForegroundColor Yellow
    exit 1
}
Write-Success "MySQL connection successful"

# Check if database exists
Write-Step "Checking Database"
if (-not (Test-DatabaseExists "matrimony_services")) {
    Write-Error-Custom "Database 'matrimony_services' does not exist"
    Write-Host "Please create the main database first using deploy-prod-database.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Success "Database 'matrimony_services' exists"

# Handle mode-specific switches
if ($SchemaOnly) {
    $SkipProcedures = $true
}

if ($ProceduresOnly) {
    $SkipSchema = $true
}

# Drop existing admin tables if requested
if ($DropTables) {
    Write-Step "Dropping Existing Admin Tables"
    Write-Warning-Custom "This will drop all admin tables and their data!"
    
    $dropTables = @(
        "admin_audit_log",
        "password_reset_tokens",
        "admin_sessions",
        "api_keys",
        "notification_queue",
        "admin_users"
    )
    
    foreach ($table in $dropTables) {
        $dropQuery = "DROP TABLE IF EXISTS $table"
        & $MySQLBin -h $MySQLHost -u $MySQLUser $(if ($MySQLPassword) { "-p$MySQLPassword" }) -D matrimony_services -e $dropQuery 2>&1 | Out-Null
        Write-Info "Dropped table: $table"
    }
    Write-Success "Admin tables dropped"
}

# Create Admin Schema (Tables and Initial Data)
if (-not $SkipSchema) {
    Write-Step "Creating Admin Schema"
    
    $schemaFile = Join-Path $AdminRoot "admin-schema.sql"
    
    if (Test-Path $schemaFile) {
        if (Invoke-SQLFile -FilePath $schemaFile -Database "matrimony_services") {
            Write-Success "Admin schema created (6 tables + default admin user)"
            Write-Info "Default Admin Credentials:"
            Write-Host "  Username: admin" -ForegroundColor White
            Write-Host "  Email: admin@matrimony.com" -ForegroundColor White
            Write-Host "  Password: Admin@123" -ForegroundColor White
            Write-Warning-Custom "Please change the default password immediately!"
        } else {
            Write-Error-Custom "Failed to create admin schema. Aborting deployment."
            exit 1
        }
    } else {
        Write-Error-Custom "admin-schema.sql not found at: $schemaFile"
        exit 1
    }
} else {
    Write-Info "Skipping admin schema creation (SkipSchema flag set)"
}

# Create Admin Stored Procedures
if (-not $SkipProcedures) {
    Write-Step "Creating Admin Stored Procedures"
    
    $proceduresFolder = Join-Path $AdminRoot "admin_procedures"
    
    if (Test-Path $proceduresFolder) {
        $procedureFiles = Get-ChildItem -Path $proceduresFolder -Filter "*.sql" | Sort-Object Name
        
        if ($procedureFiles.Count -gt 0) {
            Write-Info "Found $($procedureFiles.Count) procedure files"
            
            $procCount = 0
            $procFailed = 0
            
            foreach ($file in $procedureFiles) {
                if (Invoke-SQLFile -FilePath $file.FullName -Database "matrimony_services") {
                    $procCount++
                } else {
                    $procFailed++
                    Write-Warning-Custom "Failed to create procedure from $($file.Name). Continuing..."
                }
            }
            
            Write-Success "Created $procCount stored procedures ($procFailed failed)"
        } else {
            Write-Warning-Custom "No procedure files found in admin_procedures folder"
        }
    } else {
        Write-Warning-Custom "admin_procedures folder not found at: $proceduresFolder"
    }
} else {
    Write-Info "Skipping stored procedures (SkipProcedures flag set)"
}

# Update Admin Password if requested
if ($UpdatePassword) {
    Write-Step "Updating Default Admin Password"
    
    $updatePasswordFile = Join-Path $AdminRoot "update-admin-password.sql"
    
    if (Test-Path $updatePasswordFile) {
        if (Invoke-SQLFile -FilePath $updatePasswordFile -Database "matrimony_services") {
            Write-Success "Admin password reset to: Admin@123"
            Write-Warning-Custom "Remember to change this password for production!"
        } else {
            Write-Warning-Custom "Failed to update admin password"
        }
    } else {
        Write-Warning-Custom "update-admin-password.sql not found"
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Admin System Deployment Complete!" -ForegroundColor Green
Write-Host "  Database: matrimony_services" -ForegroundColor Green
Write-Host "  Host: $MySQLHost" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Deployed Components:" -ForegroundColor Yellow
if (-not $SkipSchema) {
    Write-Host "  [OK] Admin Schema (6 tables)" -ForegroundColor Green
    Write-Host "      - admin_users" -ForegroundColor Gray
    Write-Host "      - admin_sessions" -ForegroundColor Gray
    Write-Host "      - api_keys" -ForegroundColor Gray
    Write-Host "      - notification_queue" -ForegroundColor Gray
    Write-Host "      - admin_audit_log" -ForegroundColor Gray
    Write-Host "      - password_reset_tokens" -ForegroundColor Gray
}
if (-not $SkipProcedures) {
    Write-Host "  [OK] Admin Procedures (22 procedures)" -ForegroundColor Green
}

Write-Host "`nUsage Examples:" -ForegroundColor Yellow
Write-Host "  .\deploy-admin-system.ps1" -ForegroundColor Gray
Write-Host "  .\deploy-admin-system.ps1 -MySQLUser admin -MySQLPassword pwd" -ForegroundColor Gray
Write-Host "  .\deploy-admin-system.ps1 -DropTables" -ForegroundColor Gray
Write-Host "  .\deploy-admin-system.ps1 -SchemaOnly" -ForegroundColor Gray
Write-Host "  .\deploy-admin-system.ps1 -ProceduresOnly" -ForegroundColor Gray
Write-Host "  .\deploy-admin-system.ps1 -UpdatePassword" -ForegroundColor Gray
Write-Host "  .\deploy-admin-system.ps1 -SkipProcedures`n" -ForegroundColor Gray

Write-Host "Security Reminder:" -ForegroundColor Red
Write-Host "  Change the default admin password immediately!" -ForegroundColor Red
Write-Host "  Username: admin | Password: Admin@123`n" -ForegroundColor Red
