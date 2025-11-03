# Technical Implementation Guide
## PowerShell Computer Specs Dashboard

### Implementation Overview
This document provides technical details and implementation guidance for the PowerShell Computer Specs Dashboard project.

---

## Architecture

### Script Structure
```
Get-ComputerSpecs.ps1
├── Configuration Section
├── Data Collection Functions
│   ├── Get-CPUInfo
│   ├── Get-RAMInfo
│   ├── Get-GPUInfo
│   ├── Get-MotherboardInfo
│   ├── Get-StorageInfo (with SMART data)
│   └── Get-BootTimeInfo
├── HTML Generation
│   ├── CSS Styles (embedded)
│   ├── JavaScript (theme toggle)
│   └── HTML Structure
└── File Output & Browser Launch
```

---

## Data Collection Specifications

### 1. CPU Information
**WMI Class**: `Win32_Processor`

```powershell
Get-CimInstance -ClassName Win32_Processor
```

**Properties to collect**:
- `Name` - CPU model
- `NumberOfCores` - Physical cores
- `NumberOfLogicalProcessors` - Logical processors (with hyperthreading)
- `MaxClockSpeed` - Clock speed in MHz
- `Architecture` - Processor architecture (0=x86, 9=x64)

### 2. RAM Information
**WMI Classes**: `Win32_PhysicalMemory`, `Win32_OperatingSystem`

```powershell
# Total RAM
Get-CimInstance -ClassName Win32_PhysicalMemory

# Available/Used RAM
Get-CimInstance -ClassName Win32_OperatingSystem
```

**Properties to collect**:
- Total: Sum of all `Capacity` from Win32_PhysicalMemory
- Available: `FreePhysicalMemory` from Win32_OperatingSystem
- Calculate used and percentage

### 3. GPU & VRAM
**WMI Class**: `Win32_VideoController`

```powershell
Get-CimInstance -ClassName Win32_VideoController
```

**Properties to collect**:
- `Name` - GPU model
- `AdapterRAM` - VRAM in bytes
- Handle multiple GPUs (iterate through all)
- Convert bytes to GB for display

**Note**: Integrated GPUs may show shared system RAM

### 4. Motherboard Information
**WMI Classes**: `Win32_BaseBoard`, `Win32_PhysicalMemoryArray`

```powershell
# Motherboard model
Get-CimInstance -ClassName Win32_BaseBoard

# Max memory capacity
Get-CimInstance -ClassName Win32_PhysicalMemoryArray
```

**Properties to collect**:
- `Manufacturer` and `Product` from Win32_BaseBoard
- `MaxCapacity` from Win32_PhysicalMemoryArray (in KB)

### 5. Storage Information with SMART Data
**WMI Classes**: `Win32_DiskDrive`, `MSStorageDriver_FailurePredictStatus`, `MSStorageDriver_ATAPISmartData`

```powershell
# Basic disk info
Get-CimInstance -ClassName Win32_DiskDrive

# SMART data (requires admin)
Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus
Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_ATAPISmartData
```

**Properties to collect**:
- `Model`, `Size`, `DeviceID`
- Power-on hours from SMART attribute (ID 9)
- Calculate age from power-on hours
- Partition info for drive letters

**SMART Data Extraction**:
- Power-on hours is typically attribute ID 9
- Raw value is in bytes 5-6 of VendorSpecific array
- Convert to years/months/days for display

**Fallback**: If SMART unavailable, show "N/A" or "Not Available"

### 6. Boot Time & Uptime
**WMI Class**: `Win32_OperatingSystem`

```powershell
Get-CimInstance -ClassName Win32_OperatingSystem
```

**Properties to collect**:
- `LastBootUpTime` - DateTime of last boot
- Calculate uptime: `(Get-Date) - LastBootUpTime`
- Format as "X days, Y hours, Z minutes"

---

## HTML Dashboard Design

### Layout Structure
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Computer Specifications</title>
    <style>
        /* Embedded CSS */
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Computer Specifications</h1>
            <div class="theme-toggle">
                <!-- Toggle switch -->
            </div>
            <p class="timestamp">Generated: [timestamp]</p>
        </header>

        <div class="dashboard">
            <div class="card">CPU Information</div>
            <div class="card">RAM Information</div>
            <div class="card">GPU Information</div>
            <div class="card">Motherboard</div>
            <div class="card">Storage Drives</div>
            <div class="card">Boot Time & Uptime</div>
        </div>
    </div>
    <script>
        /* Theme toggle JavaScript */
    </script>
</body>
</html>
```

### CSS Requirements

#### Light Theme Colors
- Background: `#f5f5f5` or `#ffffff`
- Card background: `#ffffff`
- Text: `#333333` or `#000000`
- Accent: `#007acc` or similar blue

#### Dark Theme Colors
- Background: `#1e1e1e` or `#121212`
- Card background: `#2d2d2d` or `#1e1e1e`
- Text: `#e0e0e0` or `#ffffff`
- Accent: `#0098ff` or lighter blue

#### Card Styling
- Border radius: 8-12px
- Box shadow for depth
- Padding: 20-30px
- Margin between cards: 20px
- Smooth transitions on theme change

#### Responsive Design
- CSS Grid or Flexbox for card layout
- 2-3 columns on desktop
- 1 column on mobile (<768px)
- Flexible card sizing

### JavaScript - Theme Toggle

```javascript
// Theme toggle functionality
const themeToggle = document.getElementById('theme-toggle');
const body = document.body;

// Load saved theme or default to light
const savedTheme = localStorage.getItem('theme') || 'light';
body.setAttribute('data-theme', savedTheme);

themeToggle.addEventListener('click', () => {
    const currentTheme = body.getAttribute('data-theme');
    const newTheme = currentTheme === 'light' ? 'dark' : 'light';
    body.setAttribute('data-theme', newTheme);
    localStorage.setItem('theme', newTheme);
});
```

**Theme Implementation**:
- Use CSS custom properties (variables) for colors
- Use `[data-theme="dark"]` selector for dark mode
- Smooth transitions: `transition: all 0.3s ease`

---

## PowerShell Implementation Details

### Error Handling
```powershell
try {
    $data = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
} catch {
    Write-Warning "Unable to retrieve CPU information: $_"
    $data = $null
}
```

### SMART Data Parsing
```powershell
function Get-DiskAge {
    param($DiskNumber)

    try {
        $smartData = Get-CimInstance -Namespace root\wmi `
            -ClassName MSStorageDriver_ATAPISmartData `
            -ErrorAction Stop | Where-Object { $_.InstanceName -match "PCI.*$DiskNumber" }

        if ($smartData) {
            # Parse attribute 9 (Power-on hours)
            $vendorSpecific = $smartData.VendorSpecific
            # Extract power-on hours from bytes
            # Convert to years/months/days
        }
    } catch {
        return "N/A"
    }
}
```

### Admin Privilege Check
```powershell
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Warning "SMART data requires Administrator privileges. Some information may be unavailable."
}
```

### File Generation
```powershell
# Generate timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$fileName = "computer-specs-$timestamp.html"

# Get script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputPath = Join-Path $scriptPath $fileName

# Write HTML content
$htmlContent | Out-File -FilePath $outputPath -Encoding UTF8

# Open in default browser
Start-Process $outputPath
```

---

## Data Formatting Guidelines

### File Sizes
```powershell
function Format-Bytes {
    param([long]$Bytes)

    if ($Bytes -ge 1TB) { "{0:N2} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -ge 1GB) { "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { "{0:N2} MB" -f ($Bytes / 1MB) }
    else { "{0:N2} KB" -f ($Bytes / 1KB) }
}
```

### Time Formatting
```powershell
function Format-Uptime {
    param([TimeSpan]$Uptime)

    $days = $Uptime.Days
    $hours = $Uptime.Hours
    $minutes = $Uptime.Minutes

    "$days days, $hours hours, $minutes minutes"
}
```

### Percentage Display
- Show 1 decimal place
- Add visual progress bar in HTML
- Color coding: Green (0-70%), Yellow (70-85%), Red (85-100%)

---

## Testing Checklist

### Functionality Tests
- [ ] Script runs without errors on Windows 10/11
- [ ] All hardware data collected correctly
- [ ] SMART data retrieved (when admin)
- [ ] Graceful handling when not admin
- [ ] HTML file created with correct timestamp
- [ ] File saved in script directory
- [ ] Browser opens automatically
- [ ] Theme toggle works
- [ ] Theme preference persists on reload

### Visual Tests
- [ ] Layout displays correctly in Chrome
- [ ] Layout displays correctly in Edge
- [ ] Layout displays correctly in Firefox
- [ ] Responsive design works on narrow windows
- [ ] Light theme is readable
- [ ] Dark theme is readable
- [ ] Smooth transitions between themes
- [ ] Cards align properly
- [ ] Text doesn't overflow

### Edge Cases
- [ ] Handles missing SMART data
- [ ] Works with multiple GPUs
- [ ] Handles integrated graphics
- [ ] Works with multiple storage drives
- [ ] Handles drives without SMART support
- [ ] Works in virtual machines
- [ ] Handles long hardware names

---

## Performance Considerations

### Optimization Tips
- Use `Get-CimInstance` instead of `Get-WmiObject` (faster)
- Cache WMI queries where possible
- Minimize number of WMI calls
- Use `-Property` parameter to fetch only needed properties
- Async operations not needed (script is quick enough)

### Expected Execution Time
- Normal conditions: 5-10 seconds
- With SMART queries: 10-15 seconds
- Most time spent on WMI queries and SMART data

---

## Security Considerations

1. **No external dependencies** - All code embedded
2. **No network calls** - Fully offline operation
3. **No data transmission** - All data stays local
4. **Read-only operations** - No system modifications
5. **Admin privileges** - Only for SMART data (optional)

---

## Known Limitations

1. **SMART data** requires Administrator privileges
2. **Virtual machines** may have limited hardware info
3. **Older drives** may not support SMART
4. **Integrated GPUs** may show shared RAM as VRAM
5. **Windows only** - Not compatible with Linux/Mac
6. **PowerShell required** - Won't work with cmd.exe

---

## Maintenance & Updates

### Version Control
- Document version in script header
- Track changes in comments
- Keep PRD updated with changes

### Future Enhancements
When implementing future features:
1. Keep backward compatibility
2. Add new sections as separate cards
3. Maintain theme consistency
4. Document new WMI queries
5. Update this document

---

**Document Version**: 1.0
**Last Updated**: 2025-11-03
**Implementation Status**: Ready for Development
