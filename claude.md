# Implementation Notes

## WMI Classes

**CPU**: `Win32_Processor` - Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, Architecture
**RAM**: `Win32_PhysicalMemory`, `Win32_OperatingSystem` - Total capacity, FreePhysicalMemory
**GPU**: `Win32_VideoController` - Name, AdapterRAM (convert to GB)
**Motherboard**: `Win32_BaseBoard`, `Win32_PhysicalMemoryArray` - Manufacturer, Product, MaxCapacity
**Storage**: `Win32_DiskDrive`, `MSStorageDriver_ATAPISmartData` (root\wmi) - Model, Size, SMART attribute 9 for power-on hours
**Boot**: `Win32_OperatingSystem` - LastBootUpTime

## SMART Data

Parse attribute ID 9 from `VendorSpecific` array for power-on hours. Convert to years/days. Fallback to "N/A" if unavailable.

## HTML Structure

```
header (title + theme toggle + timestamp)
  └─ dashboard (grid/flex)
      ├─ CPU card
      ├─ RAM card
      ├─ GPU card
      ├─ Motherboard card
      ├─ Storage card(s)
      └─ Boot/Uptime card
```

## Theme Toggle

Use `[data-theme="light|dark"]` attribute on body. Toggle with JS, persist in localStorage. CSS variables for colors.

## File Generation

```powershell
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$fileName = "computer-specs-$timestamp.html"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputPath = Join-Path $scriptPath $fileName
$html | Out-File -FilePath $outputPath -Encoding UTF8
Start-Process $outputPath
```
