# Active Directory Management Scripts

This directory contains PowerShell scripts for managing Active Directory users, groups, and related operations.

## 📋 Available Scripts

### Add-UsersToGroupFromFile.ps1

**Purpose**: Bulk add users from a text file to an Active Directory group.

**Key Features**:

- Reads usernames from text file (one per line)
- Validates user existence in AD
- Checks for existing group memberships
- Provides detailed logging and reporting
- Supports CSV export of results

**Usage Example**:

```powershell
.\Add-UsersToGroupFromFile.ps1 -UserListPath "userlist.txt" -TargetGroupName "IT_Department"
```

### Copy-GroupMembership.ps1

**Purpose**: Copy all members from one AD group to another group.

**Key Features**:

- Validates source and target groups
- Prevents duplicate memberships
- Supports WhatIf mode for testing
- Comprehensive error handling
- Detailed reporting

**Usage Example**:

```powershell
.\Copy-GroupMembership.ps1 -SourceGroupName "IT_AllUsers" -TargetGroupName "ProjectAccess_Users" -WhatIf
```

### Export-UserInfo.ps1

**Purpose**: Export detailed user information from AD to CSV format.

**Key Features**:

- Reads usernames from input file
- Exports comprehensive user properties
- Option to include/exclude disabled accounts
- Customizable property selection
- Multiple output formats

**Usage Example**:

```powershell
.\Export-UserInfo.ps1 -InputFilePath "userlist.txt" -OutputFilePath "users_export.csv" -IncludeDisabled
```

### Export-GroupMembers.ps1

**Purpose**: Export all members of an AD group to Excel/CSV format.

**Key Features**:

- Supports nested group expansion
- Filters by object type (User, Group, Computer)
- Rich Excel formatting with ImportExcel module
- Fallback to CSV if Excel module unavailable
- Additional property inclusion

**Usage Example**:

```powershell
.\Export-GroupMembers.ps1 -GroupName "IT_Department" -Recursive -OutputPath "members.xlsx"
```

### Validate-GroupMembership.ps1

**Purpose**: Validate that users in a target group are members of required groups.

**Key Features**:

- Checks group membership requirements
- Auto-fix option to add missing memberships
- Detailed compliance reporting
- CSV export of validation results
- Comprehensive logging

**Usage Example**:

```powershell
.\Validate-GroupMembership.ps1 -TargetGroupName "Doctors" -RequiredGroups @("AllUsers", "MedicalStaff", "HeyexUsers") -AutoFix
```

## 📁 Supporting Files

### example_userlist.txt

Sample user list file for testing scripts. Contains example usernames in the correct format (one per line).

## 🔧 Prerequisites

- **Active Directory PowerShell Module**: Required for all scripts
- **Domain Permissions**: Appropriate permissions to read/modify AD objects
- **ImportExcel Module**: Optional, for enhanced Excel export functionality
- **PowerShell 5.1+**: Recommended for best compatibility

## 📥 Installation of Required Modules

```powershell
# Install Active Directory module (usually included with RSAT)
Add-WindowsFeature RSAT-AD-PowerShell

# Install ImportExcel module for enhanced Excel support
Install-Module -Name ImportExcel -Scope CurrentUser
```

## 🚀 Quick Start

1. **Prepare your user list file**:

   ```
   john.doe
   jane.smith
   admin.user
   ```

2. **Test with WhatIf mode**:

   ```powershell
   .\Add-UsersToGroupFromFile.ps1 -UserListPath "users.txt" -TargetGroupName "TestGroup" -WhatIf
   ```

3. **Run actual operation**:
   ```powershell
   .\Add-UsersToGroupFromFile.ps1 -UserListPath "users.txt" -TargetGroupName "TestGroup"
   ```

## 📊 Output Examples

All scripts generate detailed reports with statistics:

```
========= FINAL REPORT =========
Target Group: IT_Department
✔ Successfully Added: 15
🔹 Already Members: 3
❌ Not Found: 1
⚠️  Errors: 0
📁 Log File: UserGroupChanges_20250814_143022.log
📊 Detailed results exported to: UserGroupResults_20250814_143022.csv
```

## 🔍 Troubleshooting

### Common Issues

**"Active Directory module not found"**:

- Install RSAT (Remote Server Administration Tools)
- Import module manually: `Import-Module ActiveDirectory`

**"Access Denied" errors**:

- Ensure your account has appropriate AD permissions
- Run PowerShell as Administrator if needed

**"Group not found" errors**:

- Verify group names are correct and exist in AD
- Check for typos in group names

### Getting Detailed Help

Each script includes comprehensive help documentation:

```powershell
Get-Help .\Add-UsersToGroupFromFile.ps1 -Full
Get-Help .\Copy-GroupMembership.ps1 -Examples
```

## 🔒 Security Best Practices

- Always test scripts in a non-production environment first
- Use the WhatIf parameter when available to preview changes
- Review log files after operations
- Ensure proper AD permissions are assigned
- Keep scripts and logs secure, as they may contain sensitive information

## 📈 Performance Tips

- For large user lists (>1000 users), consider running during off-peak hours
- Use filters to limit scope when possible
- Monitor domain controller performance during bulk operations
- Consider batching very large operations
