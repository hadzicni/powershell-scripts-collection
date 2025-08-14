# 🪟 PowerShell Scripts Collection

A comprehensive collection of **PowerShell (.ps1)** scripts for Windows automation, system administration, Active Directory management, and IT operations. Designed for IT professionals, system administrators, and developers who want to streamline their workflows with powerful scripting solutions.

![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![License](https://img.shields.io/badge/license-Apache--2.0-blue)
![Language](https://img.shields.io/badge/language-PowerShell-blue)
![Version](https://img.shields.io/badge/version-2.0-green)

---

## 📁 Repository Structure

The scripts are organized into logical categories for easy navigation:

```
Scripts/
├── ActiveDirectory/     # User and group management, AD operations
├── SystemAdmin/        # Service monitoring, system management
├── FileOperations/     # File cleanup, batch operations
├── Network/           # Connectivity testing, device discovery
└── Utilities/         # System information, diagnostics
```

---

## 🚀 Featured Scripts

### 📋 Active Directory Management

- **Add-UsersToGroupFromFile.ps1** - Bulk add users to AD groups from text files
- **Copy-GroupMembership.ps1** - Copy users between AD groups with validation
- **Export-UserInfo.ps1** - Export detailed user information to CSV/Excel
- **Export-GroupMembers.ps1** - Export group memberships with comprehensive details
- **Validate-GroupMembership.ps1** - Validate and fix group membership requirements

### 🔧 System Administration

- **Monitor-WindowsService.ps1** - Automated service monitoring with email alerts
- **Get-LoggedOnUser.ps1** - Get current user sessions on local/remote computers

### 📁 File Operations

- **Remove-OldFiles.ps1** - Intelligent file cleanup with age/size criteria and reporting

### 🌐 Network & Device Management

- **Find-UserLastLogon.ps1** - Locate where users last logged on across the domain
- **Test-NetworkConnectivity.ps1** - Comprehensive network diagnostics and testing

### �️ Utilities

- **Get-FileArchitecture.ps1** - Determine executable architecture (32/64-bit)
- **Get-SystemInfo.ps1** - Comprehensive system information collector

---

## ✨ Key Features

- 🔍 **Comprehensive Documentation** - Every script includes detailed help with examples
- 📊 **Multiple Output Formats** - Support for CSV, JSON, HTML, and console output
- 🔒 **Error Handling** - Robust error handling and logging capabilities
- � **Progress Tracking** - Visual progress indicators for long-running operations
- 🎯 **Parameter Validation** - Input validation and helpful parameter descriptions
- 📝 **Detailed Logging** - Automatic logging with timestamps and severity levels
- 🔄 **Batch Processing** - Support for processing multiple items efficiently

---

## 🚀 Quick Start

### Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- Appropriate permissions for the operations you want to perform
- Active Directory module (for AD scripts)
- Administrative privileges (for system administration scripts)

### Installation

1. **Clone the repository:**

   ```powershell
   git clone https://github.com/hadzicni/powershell-scripts-collection.git
   cd powershell-scripts-collection
   ```

2. **Set execution policy (if needed):**

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

3. **Navigate to the Scripts directory:**
   ```powershell
   cd Scripts
   ```

### Usage Examples

#### Active Directory Operations

```powershell
# Add users from file to AD group
.\ActiveDirectory\Add-UsersToGroupFromFile.ps1 -UserListPath "users.txt" -TargetGroupName "IT_Department"

# Export group members to Excel
.\ActiveDirectory\Export-GroupMembers.ps1 -GroupName "IT_Department" -OutputPath "members.xlsx"

# Validate group memberships
.\ActiveDirectory\Validate-GroupMembership.ps1 -TargetGroupName "Doctors" -RequiredGroups @("AllUsers", "MedicalStaff")
```

#### System Administration

```powershell
# Monitor a Windows service
.\SystemAdmin\Monitor-WindowsService.ps1 -ServiceName "ImportantService" -EmailNotification

# Get logged on users
.\SystemAdmin\Get-LoggedOnUser.ps1 -ComputerName "SERVER01" -IncludeProcesses
```

#### File Operations

```powershell
# Clean up old files
.\FileOperations\Remove-OldFiles.ps1 -Path "C:\Logs" -AgeInDays 30 -FilePattern "*.log" -Recurse
```

#### Network Diagnostics

```powershell
# Test network connectivity
.\Network\Test-NetworkConnectivity.ps1 -Target "server.company.com" -TestType All -Detailed

# Find user's last logon location
.\Network\Find-UserLastLogon.ps1 -Username "john.doe" -MaxDaysBack 7
```

#### Utilities

```powershell
# Get system information
.\Utilities\Get-SystemInfo.ps1 -OutputFormat HTML -IncludeSoftware -IncludeNetworking

# Check file architecture
.\Utilities\Get-FileArchitecture.ps1 -Path "C:\Program Files" -Recurse -OutputFormat CSV
```

---

## 📚 Script Documentation

Each script includes comprehensive help documentation. Use `Get-Help` to view detailed information:

```powershell
Get-Help .\ActiveDirectory\Add-UsersToGroupFromFile.ps1 -Full
Get-Help .\SystemAdmin\Monitor-WindowsService.ps1 -Examples
```

---

## 🔒 Security Considerations

- **Principle of Least Privilege**: Run scripts with minimum required permissions
- **Credential Handling**: Use secure credential objects, avoid plain text passwords
- **Input Validation**: All scripts include input validation and sanitization
- **Logging**: Sensitive operations are logged for audit purposes
- **Testing**: Always test scripts in a non-production environment first

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Adding New Scripts

1. **Follow the established structure**: Place scripts in appropriate category folders
2. **Include comprehensive documentation**: Use PowerShell's comment-based help
3. **Add error handling**: Implement proper try-catch blocks and logging
4. **Support multiple output formats**: Where applicable, support CSV, JSON, HTML outputs
5. **Include examples**: Provide practical usage examples

### Improving Existing Scripts

- Optimize performance for large datasets
- Add new features or output formats
- Improve error handling and user experience
- Update documentation and examples

### Reporting Issues

- Use GitHub Issues to report bugs or request features
- Include PowerShell version, OS version, and error details
- Provide steps to reproduce the issue

---

## 📋 Requirements by Category

### Active Directory Scripts

- Active Directory PowerShell module
- Domain user account with appropriate permissions
- Access to domain controllers

### System Administration Scripts

- Local or remote administrative privileges
- PowerShell Remoting (for remote operations)
- Appropriate service permissions

### Network Scripts

- Network connectivity to target systems
- WinRM enabled (for remote operations)
- Appropriate firewall configurations

---

## � Troubleshooting

### Common Issues

**Execution Policy Errors:**

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**Module Import Errors:**

```powershell
# For Active Directory module
Import-Module ActiveDirectory
```

**Remote Access Issues:**

```powershell
# Enable PowerShell Remoting
Enable-PSRemoting -Force
```

### Getting Help

1. Check the script's built-in help: `Get-Help .\script-name.ps1 -Full`
2. Review the log files generated by scripts
3. Check Windows Event Logs for system-related issues
4. Open an issue on GitHub for script-specific problems

---

## 📄 License

This project is licensed under the Apache License 2.0. See the [LICENSE](./LICENSE) file for details.

---

## 👨‍💻 Author

**Nikola Hadzic**

- GitHub: [@hadzicni](https://github.com/hadzicni)
- Organization: University Hospital Basel

---

## 🙏 Acknowledgments

- Microsoft PowerShell team for the excellent scripting platform
- IT community for sharing knowledge and best practices
- Contributors who help improve these scripts

---

## 📈 Version History

- **v2.0** (2025-08-14): Major reorganization, improved documentation, new scripts
- **v1.0** (2025-01-14): Initial collection of basic scripts

---

_Happy scripting! 🚀_
