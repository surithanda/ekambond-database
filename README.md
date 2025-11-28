# Matrimony Services - Production Database

Production-ready MySQL database scripts for the Matrimony Services platform.

## 📋 Overview

This repository contains clean, organized SQL scripts for deploying the `matrimony_services` database. All scripts have been cleaned from MySQL dump metadata and are formatted for easy reading and version control.

## 🗂️ Structure

```
prod-database/
├── Deploy/                              # Deployment scripts
│   ├── deploy-prod-database.ps1         # Main PowerShell deployment script
│   ├── deploy-prod-database.bat         # Windows batch wrapper
│   ├── DEPLOYMENT_README.md             # Detailed deployment guide
│   └── QUICK_START.md                   # Quick reference
│
├── initial-data/                        # Optional data files
│   ├── README.md                        # Data folder documentation
│   └── *_data.sql                       # INSERT statements (12 files)
│
├── create_database.sql                  # Database creation
├── matrimony_services_*.sql             # Table definitions (26 files)
└── matrimony_services_routines.sql      # Stored procedures (75 procedures)
```

## 🚀 Quick Start

### Prerequisites
- MySQL Server 8.0 or higher
- PowerShell (Windows) or Bash (Linux/Mac)
- Admin credentials for MySQL

### Default Deployment

```powershell
cd Deploy
.\deploy-prod-database.ps1
```

### Drop and Recreate

```powershell
.\deploy-prod-database.ps1 -DropExisting
```

### Custom Credentials

```powershell
.\deploy-prod-database.ps1 -MySQLUser "admin" -MySQLPassword "yourpassword"
```

## 📊 Database Contents

### Tables (26)
- **Account Management**: account, login, login_history
- **Profile Data**: profile_personal, profile_address, profile_contact, profile_education, profile_employment, profile_family_reference, profile_photo, profile_property
- **Profile Interactions**: profile_favorites, profile_views, profile_contacted, profile_saved_for_later, profile_search_preference, profile_hobby_interest, profile_lifestyle
- **Reference Data**: country, state, lookup_table
- **Partners**: registered_partner, api_clients
- **Payments**: stripe_payment_intents
- **System**: activity_log, test

### Data Files (12)
- **1,153 total rows** across 12 tables
- Reference data: 25 countries, 87 states, 480 lookup values
- Sample production data: 12 accounts, 518 activity logs

### Stored Procedures (75)
- Account management and authentication
- Profile CRUD operations
- Admin operations
- API client management
- Activity logging

## 🎯 Deployment Options

| Command | Description |
|---------|-------------|
| `.\deploy-prod-database.ps1` | Full deployment (default) |
| `-DropExisting` | Drop and recreate everything |
| `-TablesOnly` | Create only table structures |
| `-DataOnly` | Insert only data (tables must exist) |
| `-RoutinesOnly` | Create only stored procedures |
| `-SkipData` | Deploy without data |
| `-SkipRoutines` | Deploy without stored procedures |

## 📝 Features

✅ **Clean SQL** - No MySQL dump metadata or session variables  
✅ **Separated Data** - Data files separate from table definitions  
✅ **Normalized** - No AUTO_INCREMENT values or redundant charset declarations  
✅ **Formatted** - Multi-line INSERT statements for readability  
✅ **Automated** - Fully automated deployment with options  
✅ **Version Control Ready** - Formatted for git diffs  

## 🔧 Manual Deployment

If you prefer manual deployment:

```bash
# 1. Create database
mysql -u root -p < create_database.sql

# 2. Create tables
mysql -u root -p matrimony_services < matrimony_services_account.sql
# ... repeat for all table files

# 3. Insert data (optional)
mysql -u root -p matrimony_services < initial-data/matrimony_services_account_data.sql
# ... repeat for all data files

# 4. Create stored procedures
mysql -u root -p matrimony_services < matrimony_services_routines.sql
```

## ⚙️ Configuration

Update MySQL binary path in `deploy-prod-database.ps1` if needed:

```powershell
$MySQLBin = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
```

## 📖 Documentation

- **[DEPLOYMENT_README.md](Deploy/DEPLOYMENT_README.md)** - Complete deployment guide
- **[QUICK_START.md](Deploy/QUICK_START.md)** - Quick reference commands
- **[initial-data/README.md](initial-data/README.md)** - Data files documentation

## ⚠️ Important Notes

1. **Backup First**: Always backup existing database before using `-DropExisting`
2. **Password Security**: Use environment variables or secure credential storage in production
3. **Character Set**: Database uses `utf8mb4` with `utf8mb4_0900_ai_ci` collation
4. **Version**: Designed for MySQL 8.0+

## 🐛 Troubleshooting

### Cannot connect to MySQL
- Verify MySQL service is running
- Check credentials (username/password)
- Ensure firewall allows connections

### Failed to create routines
- Ensure tables exist before creating routines
- Verify user has CREATE ROUTINE privilege
- Check MySQL version compatibility

### Data insertion errors
- Ensure tables are created first
- Check for foreign key constraints
- Verify data file format

## 📄 License

[Add your license here]

## 👥 Contributors

[Add contributors here]

## 📞 Support

For issues or questions, please [create an issue](../../issues) in this repository.

---

**Database Version**: Production Export (November 2025)  
**MySQL Version**: 8.0+  
**Total Objects**: 26 tables, 75 procedures, 1,153 data rows
