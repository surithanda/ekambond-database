# 🚀 Quick Start Guide - Production Database Deployment

## One-Liner Deployments

### Default Deployment (Easiest)
```batch
deploy-prod-database.bat
```
*Creates everything: database, tables with data, and routines*

### Fresh Start (Drop Everything)
```powershell
.\deploy-prod-database.ps1 -DropExisting
```
*Drops existing database and recreates everything*

### Custom Credentials
```powershell
.\deploy-prod-database.ps1 -MySQLUser "myuser" -MySQLPassword "mypass"
```

## Common Scenarios

| Scenario | Command |
|----------|---------|
| **Full deployment (with data)** | `.\deploy-prod-database.ps1` |
| **Drop and recreate all** | `.\deploy-prod-database.ps1 -DropExisting` |
| **Structure only (no data)** | `.\deploy-prod-database.ps1 -TablesOnly` |
| **Tables without data** | `.\deploy-prod-database.ps1 -SkipData` |
| **Load data only** | `.\deploy-prod-database.ps1 -DataOnly` |
| **Update routines only** | `.\deploy-prod-database.ps1 -RoutinesOnly` |
| **Remote server** | `.\deploy-prod-database.ps1 -MySQLHost "192.168.1.100"` |

## Parameters Quick Reference

| Flag | Effect |
|------|--------|
| `-DropExisting` | 🔴 Drops database first (CAUTION!) |
| `-TablesOnly` | Only create table structures |
| `-DataOnly` | Only insert data (tables must exist) |
| `-RoutinesOnly` | Only create stored procedures/functions |
| `-SkipData` | Skip data insertion |
| `-SkipRoutines` | Skip stored procedures/functions |
| `-SkipTables` | Skip table creation |

## What Gets Deployed?

✅ **Database**: `matrimony_services`  
✅ **Tables**: 26 tables (DDL only - account, login, profiles, etc.)  
✅ **Data**: 13 data files in `initial-data/` folder (optional)  
✅ **Routines**: 80+ stored procedures and functions  

💡 **New**: Data is now **separate** from table definitions for better control!  

## Need Help?

📖 Full documentation: [DEPLOYMENT_README.md](DEPLOYMENT_README.md)

## ⚠️ Before You Start

1. ✅ MySQL Server 8.0+ is running
2. ✅ You have admin credentials
3. ✅ Backup existing database (if any)
4. ✅ Update `$MySQLBin` path if needed (in .ps1 file)

---

**Default MySQL Path**: `C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe`  
**Default Credentials**: `root` / `NewStrongPassword123!` (update as needed)
