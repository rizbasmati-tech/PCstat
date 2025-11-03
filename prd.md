# Product Requirements Document (PRD)
## PowerShell Computer Specs Dashboard

### Project Overview
A PowerShell script that collects and displays comprehensive computer specifications in a web-friendly HTML format with a modern dashboard interface.

---

## 1. Objectives
- Provide a comprehensive overview of computer hardware specifications
- Present data in an easily readable, visually appealing web format
- Enable quick assessment of system capabilities and drive health
- Track system boot time and uptime

---

## 2. Functional Requirements

### 2.1 Data Collection

#### 2.1.1 CPU Information
- Model/Name
- Number of cores
- Clock speed
- Architecture

#### 2.1.2 RAM Information
- Total capacity
- Available memory
- Used memory
- Usage percentage

#### 2.1.3 GPU & VRAM
- GPU model(s) for all graphics adapters
- VRAM available for each GPU
- Support for both integrated and dedicated GPUs

#### 2.1.4 Motherboard
- Model name
- Manufacturer
- Maximum memory capacity supported

#### 2.1.5 Storage Drives
**Scope**: All storage drives detected
- Drive letter/identifier
- Model/Manufacturer
- Total capacity
- Used space
- Free space
- Drive age using SMART data (power-on hours)
- Health status (if available from SMART data)

#### 2.1.6 Boot Time & Uptime
- Last boot date and time
- System uptime (formatted as days, hours, minutes)

### 2.2 Output Requirements

#### 2.2.1 File Format
- HTML5 format with embedded CSS and JavaScript
- Self-contained (no external dependencies)

#### 2.2.2 File Naming
- Pattern: `computer-specs-YYYY-MM-DD_HH-MM-SS.html`
- Timestamped to maintain history of reports
- Example: `computer-specs-2025-11-03_14-30-25.html`

#### 2.2.3 Save Location
- Same directory as the PowerShell script
- No additional folder creation required

### 2.3 User Interface Requirements

#### 2.3.1 Layout
- Modern card-based dashboard design
- Organized sections for each hardware category
- Responsive design for different screen sizes
- Generation timestamp displayed prominently

#### 2.3.2 Theme Support
- Light theme (default)
- Dark theme
- Toggle switch for seamless theme switching
- Theme preference persisted in browser (if possible)
- Smooth transitions between themes

#### 2.3.3 Visual Design
- Professional appearance suitable for technical reporting
- Clear typography and spacing
- Visual indicators for storage capacity (progress bars)
- Icons or visual elements to enhance readability
- Color coding for status indicators (e.g., drive health)

### 2.4 Script Behavior

#### 2.4.1 Execution
- Single PowerShell script file
- No external dependencies or modules required
- Graceful handling of missing/unavailable data
- Error messages displayed in output if data collection fails

#### 2.4.2 Auto-Open Feature
- Automatically open generated HTML file in default browser
- Use system default browser (not Chrome-specific)
- Execute immediately after file generation

#### 2.4.3 Permissions
- Attempt to use SMART data (may require admin privileges)
- Provide fallback or informative message if admin rights unavailable
- Script should not fail completely if some data unavailable

---

## 3. Technical Requirements

### 3.1 PowerShell Version
- Compatible with PowerShell 5.1+ (Windows PowerShell)
- Consider PowerShell 7+ compatibility if possible

### 3.2 Data Sources
- WMI/CIM cmdlets for hardware information
- `Get-CimInstance` preferred over `Get-WmiObject`
- SMART data via WMI classes (e.g., `MSStorageDriver_FailurePredictStatus`)
- System event logs for boot time information

### 3.3 HTML/CSS/JavaScript
- Valid HTML5
- Modern CSS (Flexbox/Grid for layout)
- Vanilla JavaScript (no framework dependencies)
- Cross-browser compatible (Chrome, Edge, Firefox)

---

## 4. Non-Functional Requirements

### 4.1 Performance
- Script execution should complete within 10-15 seconds
- Minimal system resource usage during data collection
- HTML file should load instantly in browser

### 4.2 Usability
- Clear, readable output
- Professional presentation suitable for IT reports
- Intuitive theme toggle
- No user interaction required during script execution

### 4.3 Maintainability
- Well-commented PowerShell code
- Modular structure for easy updates
- Clear error messages for troubleshooting

### 4.4 Reliability
- Handle missing or unavailable hardware information gracefully
- Provide meaningful error messages
- Don't crash if SMART data unavailable
- Fallback values for missing data points

---

## 5. Constraints & Limitations

### 5.1 Platform
- Windows operating system only
- PowerShell execution policy must allow script execution

### 5.2 Permissions
- SMART data may require Administrator privileges
- Some WMI queries may require elevated permissions

### 5.3 Hardware Support
- SMART data availability depends on drive support
- Older drives may not provide age information
- Virtual machines may have limited hardware information

---

## 6. Success Criteria

1. Script successfully collects all specified hardware information
2. HTML output displays all data in a visually appealing dashboard
3. Theme toggle works smoothly between light and dark modes
4. File is automatically opened in default browser
5. Script handles missing data gracefully without errors
6. Output is readable and professional in appearance

---

## 7. Future Enhancements (Out of Scope)

- Auto-refresh capability
- Network information
- Temperature monitoring
- Historical trend tracking
- Export to other formats (PDF, JSON)
- Remote system querying
- Comparison between multiple reports

---

## 8. Acceptance Criteria

- [ ] Script runs successfully on Windows 10/11
- [ ] All hardware categories display correct information
- [ ] SMART data shows drive age in human-readable format
- [ ] HTML file opens automatically in default browser
- [ ] Theme toggle switches between light and dark modes
- [ ] Timestamped files are created in script directory
- [ ] Layout is responsive and displays well on different screen sizes
- [ ] Script provides clear error messages for missing data
- [ ] Code is well-documented and maintainable

---

**Document Version**: 1.0
**Last Updated**: 2025-11-03
**Status**: Approved for Implementation
