# MySQL Production Database Deployment Script
# This script deploys the matrimony_services database from production dumps

param(
    [Parameter(Mandatory=$false)]
    [string]$MySQLHost = "localhost",
    
    [Parameter(Mandatory=$false)]
    [string]$MySQLUser = "root",
    
    [Parameter(Mandatory=$false)]
    [string]$MySQLPassword = "NewStrongPassword123!",
    
    [Parameter(Mandatory=$false)]
    [switch]$DropDatabase,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateDatabase,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTables,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipData,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipRoutines,
    
    [Parameter(Mandatory=$false)]
    [switch]$TablesOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$DataOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$RoutinesOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$DropExisting
)

$MySQLBin = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
$ScriptRoot = Split-Path -Parent $PSCommandPath
$ProdDatabaseRoot = Split-Path -Parent $ScriptRoot

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

# Execute SQL file
function Invoke-SQLFile {
    param(
        [string]$FilePath,
        [string]$Database = ""
    )
    
    $fileName = Split-Path $FilePath -Leaf
    Write-Info "Executing: $fileName"
    
    try {
        # Use Get-Content and pipe to mysql for proper DELIMITER handling
        if ($Database) {
            $result = Get-Content $FilePath -Raw | & $MySQLBin -h $MySQLHost -u $MySQLUser $(if ($MySQLPassword) { "-p$MySQLPassword" }) $Database 2>&1
        } else {
            $result = Get-Content $FilePath -Raw | & $MySQLBin -h $MySQLHost -u $MySQLUser $(if ($MySQLPassword) { "-p$MySQLPassword" }) 2>&1
        }
        
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
Write-Host "  MySQL Production Database Deployment" -ForegroundColor Magenta
Write-Host "  Database: matrimony_services" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# Check if MySQL binary exists
if (-not (Test-Path $MySQLBin)) {
    Write-Error-Custom "MySQL binary not found at: $MySQLBin"
    Write-Host "Please update the `$MySQLBin variable in this script to point to your MySQL installation" -ForegroundColor Yellow
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

# Handle DropExisting backward compatibility
if ($DropExisting) {
    $DropDatabase = $true
    $CreateDatabase = $true
}

# Handle mode-specific switches
if ($TablesOnly) {
    $SkipRoutines = $true
    $SkipData = $true
}

if ($DataOnly) {
    $SkipTables = $true
    $SkipRoutines = $true
}

if ($RoutinesOnly) {
    $SkipTables = $true
    $SkipData = $true
}

# Drop existing database if requested
if ($DropDatabase) {
    Write-Step "Dropping Existing Database"
    $dropQuery = "DROP DATABASE IF EXISTS matrimony_services"
    & $MySQLBin -h $MySQLHost -u $MySQLUser $(if ($MySQLPassword) { "-p$MySQLPassword" }) -e $dropQuery 2>&1 | Out-Null
    Write-Success "Existing database dropped"
}

# Create Database
if ($CreateDatabase -or (-not $DropDatabase -and -not $SkipTables)) {
    Write-Step "Creating Database"
    $createDbFile = Join-Path $ProdDatabaseRoot "create_database.sql"
    if (Test-Path $createDbFile) {
        if (-not (Invoke-SQLFile -FilePath $createDbFile)) {
            Write-Error-Custom "Failed to create database. Aborting deployment."
            exit 1
        }
    } else {
        Write-Warning-Custom "create_database.sql not found. Assuming database exists."
    }
} else {
    Write-Info "Skipping database creation"
}

# Get all table SQL files (excluding routines)
$tableFiles = Get-ChildItem -Path $ProdDatabaseRoot -Filter "matrimony_services_*.sql" | 
    Where-Object { $_.Name -ne "matrimony_services_routines.sql" } | 
    Sort-Object Name

# Get data files from initial-data folder
$initialDataFolder = Join-Path $ProdDatabaseRoot "initial-data"
$dataFiles = @()
if (Test-Path $initialDataFolder) {
    $dataFiles = Get-ChildItem -Path $initialDataFolder -Filter "*_data.sql" | Sort-Object Name
}

# Create Tables (structure only - no data in these files anymore)
if (-not $SkipTables) {
    Write-Step "Creating Tables"
    Write-Info "Found $($tableFiles.Count) table files"
    
    $tableCount = 0
    $tableFailed = 0
    
    foreach ($file in $tableFiles) {
        if (Invoke-SQLFile -FilePath $file.FullName -Database "matrimony_services") {
            $tableCount++
        } else {
            $tableFailed++
            Write-Warning-Custom "Failed to create table from $($file.Name). Continuing..."
        }
    }
    
    Write-Success "Created $tableCount tables ($tableFailed failed)"
} else {
    Write-Info "Skipping table creation (SkipTables flag set)"
}

# Insert Data from initial-data folder
if (-not $SkipData) {
    Write-Step "Inserting Initial Data"
    
    if ($dataFiles.Count -gt 0) {
        Write-Info "Found $($dataFiles.Count) data files in initial-data folder"
        
        $dataCount = 0
        $dataFailed = 0
        
        foreach ($file in $dataFiles) {
            if (Invoke-SQLFile -FilePath $file.FullName -Database "matrimony_services") {
                $dataCount++
            } else {
                $dataFailed++
                Write-Warning-Custom "Failed to insert data from $($file.Name). Continuing..."
            }
        }
        
        Write-Success "Inserted data for $dataCount tables ($dataFailed failed)"
    } else {
        Write-Warning-Custom "No data files found in initial-data folder"
    }
} else {
    Write-Info "Skipping data insertion (SkipData flag set)"
}

# Create Stored Procedures and Functions
if (-not $SkipRoutines) {
    Write-Step "Creating Stored Procedures and Functions"
    
    $routinesFile = Join-Path $ProdDatabaseRoot "matrimony_services_routines.sql"
    
    if (Test-Path $routinesFile) {
        if (Invoke-SQLFile -FilePath $routinesFile -Database "matrimony_services") {
            # Try to count procedures/functions in the file
            $content = Get-Content $routinesFile -Raw
            $procCount = ([regex]::Matches($content, "DROP PROCEDURE")).Count
            $funcCount = ([regex]::Matches($content, "DROP FUNCTION")).Count
            Write-Success "Created $procCount stored procedures and $funcCount functions"
        } else {
            Write-Error-Custom "Failed to create routines. Check the error above."
        }
    } else {
        Write-Warning-Custom "Routines file not found: matrimony_services_routines.sql"
    }
} else {
    Write-Info "Skipping stored procedures and functions (SkipRoutines flag set)"
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "  Database: matrimony_services" -ForegroundColor Green
Write-Host "  Host: $MySQLHost" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host "  .\deploy-prod-database.ps1" -ForegroundColor Gray
Write-Host "  .\deploy-prod-database.ps1 -MySQLUser admin -MySQLPassword pwd" -ForegroundColor Gray
Write-Host "  .\deploy-prod-database.ps1 -DropDatabase -CreateDatabase" -ForegroundColor Gray
Write-Host "  .\deploy-prod-database.ps1 -DropExisting" -ForegroundColor Gray
Write-Host "  .\deploy-prod-database.ps1 -TablesOnly" -ForegroundColor Gray
Write-Host "  .\deploy-prod-database.ps1 -DataOnly" -ForegroundColor Gray
Write-Host "  .\deploy-prod-database.ps1 -RoutinesOnly" -ForegroundColor Gray
Write-Host "  .\deploy-prod-database.ps1 -SkipData" -ForegroundColor Gray
Write-Host "  .\deploy-prod-database.ps1 -SkipRoutines`n" -ForegroundColor Gray
