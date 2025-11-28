# Initial Data Files

This folder contains INSERT statements extracted from table definition files.

## Purpose

These data files are separated from table structures to allow flexible deployment:
- Deploy tables without data (for empty database setup)
- Deploy data independently when needed
- Refresh data without recreating tables

## File Naming Convention

Files are named: `matrimony_services_<tablename>_data.sql`

Example:
- `matrimony_services_account_data.sql` - Data for account table
- `matrimony_services_country_data.sql` - Data for country table

## Usage

### Load All Data
```powershell
# Using the deployment script
.\Deploy\deploy-prod-database.ps1 -DataOnly
```

### Load Specific Table Data
```bash
mysql -u root -p matrimony_services < matrimony_services_account_data.sql
```

### Load All Data Manually
```bash
# Linux/Mac
for file in *.sql; do mysql -u root -p matrimony_services < "$file"; done

# Windows PowerShell
Get-ChildItem -Filter "*.sql" | ForEach-Object { 
    mysql -u root -p matrimony_services -e "source $($_.FullName)" 
}
```

## Notes

- These files contain production data exported from the source database
- INSERT statements use the format: `INSERT INTO table VALUES (...)`
- Ensure tables exist before running these scripts
- Some tables may not have data files (empty tables)
