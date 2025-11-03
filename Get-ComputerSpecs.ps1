#Requires -Version 5.1
<#
.SYNOPSIS
    Collects computer specifications and generates an HTML dashboard.

.DESCRIPTION
    Gathers CPU, RAM, GPU, Motherboard, Storage (with SMART data), and Boot/Uptime information.
    Outputs a timestamped HTML file with light/dark theme toggle.

.NOTES
    Version: 1.0
    SMART data collection requires Administrator privileges.
#>

# Helper Functions
function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    else { return "$Bytes Bytes" }
}

function Format-Uptime {
    param([TimeSpan]$Uptime)
    return "$($Uptime.Days) days, $($Uptime.Hours) hours, $($Uptime.Minutes) minutes"
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Data Collection Functions
function Get-CPUInfo {
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $arch = switch ($cpu.Architecture) {
            0 { "x86" }
            9 { "x64" }
            12 { "ARM64" }
            default { "Unknown" }
        }
        return @{
            Name = $cpu.Name
            Cores = $cpu.NumberOfCores
            LogicalProcessors = $cpu.NumberOfLogicalProcessors
            ClockSpeed = "$($cpu.MaxClockSpeed) MHz"
            Architecture = $arch
        }
    } catch {
        Write-Warning "Failed to retrieve CPU info: $_"
        return $null
    }
}

function Get-RAMInfo {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $totalRAM = (Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction Stop |
                     Measure-Object -Property Capacity -Sum).Sum
        $freeRAM = $os.FreePhysicalMemory * 1KB
        $usedRAM = $totalRAM - $freeRAM
        $usagePercent = [math]::Round(($usedRAM / $totalRAM) * 100, 1)

        return @{
            Total = Format-Bytes $totalRAM
            Used = Format-Bytes $usedRAM
            Available = Format-Bytes $freeRAM
            UsagePercent = $usagePercent
        }
    } catch {
        Write-Warning "Failed to retrieve RAM info: $_"
        return $null
    }
}

function Get-GPUInfo {
    try {
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
        $gpuList = @()
        foreach ($gpu in $gpus) {
            $vram = if ($gpu.AdapterRAM -gt 0) {
                Format-Bytes $gpu.AdapterRAM
            } else {
                "Shared/Unknown"
            }
            $gpuList += @{
                Name = $gpu.Name
                VRAM = $vram
            }
        }
        return $gpuList
    } catch {
        Write-Warning "Failed to retrieve GPU info: $_"
        return @()
    }
}

function Get-MotherboardInfo {
    try {
        $board = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
        $memArray = Get-CimInstance -ClassName Win32_PhysicalMemoryArray -ErrorAction Stop | Select-Object -First 1
        $maxCapacity = if ($memArray.MaxCapacity) {
            Format-Bytes ($memArray.MaxCapacity * 1KB)
        } else {
            "Unknown"
        }

        return @{
            Manufacturer = $board.Manufacturer
            Model = $board.Product
            MaxMemoryCapacity = $maxCapacity
        }
    } catch {
        Write-Warning "Failed to retrieve Motherboard info: $_"
        return $null
    }
}

function Get-StorageInfo {
    $isAdmin = Test-Administrator
    if (-not $isAdmin) {
        Write-Warning "Not running as Administrator. SMART data may be unavailable."
    }

    try {
        $disks = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop
        $diskList = @()

        foreach ($disk in $disks) {
            $diskNumber = $disk.Index
            $partitions = Get-CimInstance -ClassName Win32_DiskDriveToDiskPartition -ErrorAction SilentlyContinue |
                         Where-Object { $_.Antecedent.DeviceID -eq $disk.DeviceID }

            $driveLetters = @()
            foreach ($partition in $partitions) {
                $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDiskToPartition -ErrorAction SilentlyContinue |
                               Where-Object { $_.Antecedent.DeviceID -eq $partition.Dependent.DeviceID }
                foreach ($ld in $logicalDisks) {
                    $letter = $ld.Dependent.DeviceID -replace '.*"(.*)".*', '$1'
                    if ($letter) { $driveLetters += $letter }
                }
            }

            $usedSpace = 0
            $freeSpace = 0
            foreach ($letter in $driveLetters) {
                $vol = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$letter'" -ErrorAction SilentlyContinue
                if ($vol) {
                    $usedSpace += ($vol.Size - $vol.FreeSpace)
                    $freeSpace += $vol.FreeSpace
                }
            }

            # Try to get SMART data
            $age = "N/A"
            $health = "Unknown"
            if ($isAdmin) {
                try {
                    $smartData = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_ATAPISmartData -ErrorAction SilentlyContinue |
                                Where-Object { $_.InstanceName -match "_$diskNumber" }

                    if ($smartData -and $smartData.VendorSpecific) {
                        # Parse SMART attributes (attribute 9 = power-on hours)
                        $vendorData = $smartData.VendorSpecific
                        for ($i = 2; $i -lt $vendorData.Length - 5; $i += 12) {
                            $attrId = $vendorData[$i]
                            if ($attrId -eq 9) {  # Power-on hours
                                $rawValue = [BitConverter]::ToUInt32($vendorData[($i+5)..($i+8)], 0)
                                $hours = $rawValue
                                $days = [math]::Floor($hours / 24)
                                $years = [math]::Floor($days / 365)
                                $remainingDays = $days % 365
                                $age = if ($years -gt 0) { "$years years, $remainingDays days" } else { "$days days" }
                                break
                            }
                        }
                    }

                    # Try to get health status
                    $failPredict = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue |
                                  Where-Object { $_.InstanceName -match "_$diskNumber" }
                    if ($failPredict) {
                        $health = if ($failPredict.PredictFailure) { "Warning" } else { "Healthy" }
                    }
                } catch {
                    # SMART data unavailable for this disk
                }
            }

            $diskList += @{
                Model = $disk.Model
                Letters = if ($driveLetters.Count -gt 0) { $driveLetters -join ", " } else { "No mount" }
                TotalSize = Format-Bytes $disk.Size
                UsedSpace = Format-Bytes $usedSpace
                FreeSpace = Format-Bytes $freeSpace
                UsagePercent = if ($disk.Size -gt 0) { [math]::Round(($usedSpace / $disk.Size) * 100, 1) } else { 0 }
                Age = $age
                Health = $health
            }
        }

        return $diskList
    } catch {
        Write-Warning "Failed to retrieve Storage info: $_"
        return @()
    }
}

function Get-BootTimeInfo {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $lastBoot = $os.LastBootUpTime
        $uptime = (Get-Date) - $lastBoot

        return @{
            LastBootTime = $lastBoot.ToString("yyyy-MM-dd HH:mm:ss")
            Uptime = Format-Uptime $uptime
        }
    } catch {
        Write-Warning "Failed to retrieve Boot info: $_"
        return $null
    }
}

# Collect all data
Write-Host "Collecting system information..." -ForegroundColor Cyan
$cpu = Get-CPUInfo
$ram = Get-RAMInfo
$gpus = Get-GPUInfo
$motherboard = Get-MotherboardInfo
$storage = Get-StorageInfo
$boot = Get-BootTimeInfo

# Generate HTML
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Build GPU cards HTML
$gpuCardsHtml = ""
foreach ($gpu in $gpus) {
    $gpuCardsHtml += @"
                    <div class="info-row">
                        <span class="label">$($gpu.Name)</span>
                        <span class="value">$($gpu.VRAM)</span>
                    </div>
"@
}

# Build Storage cards HTML
$storageCardsHtml = ""
foreach ($disk in $storage) {
    $healthClass = switch ($disk.Health) {
        "Healthy" { "health-good" }
        "Warning" { "health-warning" }
        default { "health-unknown" }
    }
    $storageCardsHtml += @"
                    <div class="storage-item">
                        <div class="info-row">
                            <span class="label">Model</span>
                            <span class="value">$($disk.Model)</span>
                        </div>
                        <div class="info-row">
                            <span class="label">Drive Letters</span>
                            <span class="value">$($disk.Letters)</span>
                        </div>
                        <div class="info-row">
                            <span class="label">Total Size</span>
                            <span class="value">$($disk.TotalSize)</span>
                        </div>
                        <div class="info-row">
                            <span class="label">Used / Free</span>
                            <span class="value">$($disk.UsedSpace) / $($disk.FreeSpace)</span>
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $($disk.UsagePercent)%"></div>
                        </div>
                        <div class="progress-label">$($disk.UsagePercent)% Used</div>
                        <div class="info-row">
                            <span class="label">Age</span>
                            <span class="value">$($disk.Age)</span>
                        </div>
                        <div class="info-row">
                            <span class="label">Health</span>
                            <span class="value $healthClass">$($disk.Health)</span>
                        </div>
                    </div>
"@
}

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Computer Specifications</title>
    <style>
        :root {
            --bg-primary: #f5f5f5;
            --bg-secondary: #ffffff;
            --text-primary: #333333;
            --text-secondary: #666666;
            --accent: #007acc;
            --border: #e0e0e0;
            --shadow: rgba(0, 0, 0, 0.1);
            --progress-bg: #e0e0e0;
            --progress-fill: #007acc;
            --health-good: #4caf50;
            --health-warning: #ff9800;
            --health-unknown: #757575;
        }

        [data-theme="dark"] {
            --bg-primary: #1e1e1e;
            --bg-secondary: #2d2d2d;
            --text-primary: #e0e0e0;
            --text-secondary: #b0b0b0;
            --accent: #0098ff;
            --border: #404040;
            --shadow: rgba(0, 0, 0, 0.3);
            --progress-bg: #404040;
            --progress-fill: #0098ff;
            --health-good: #66bb6a;
            --health-warning: #ffa726;
            --health-unknown: #9e9e9e;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            transition: background 0.3s ease, color 0.3s ease;
            padding: 20px;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
        }

        header {
            text-align: center;
            margin-bottom: 40px;
        }

        h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            color: var(--accent);
        }

        .header-info {
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 20px;
            flex-wrap: wrap;
        }

        .timestamp {
            color: var(--text-secondary);
            font-size: 0.9rem;
        }

        .theme-toggle {
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 10px;
            padding: 8px 16px;
            background: var(--bg-secondary);
            border: 1px solid var(--border);
            border-radius: 20px;
            transition: all 0.3s ease;
        }

        .theme-toggle:hover {
            transform: scale(1.05);
            box-shadow: 0 2px 8px var(--shadow);
        }

        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
        }

        .card {
            background: var(--bg-secondary);
            border-radius: 12px;
            padding: 24px;
            box-shadow: 0 2px 8px var(--shadow);
            transition: all 0.3s ease;
        }

        .card:hover {
            box-shadow: 0 4px 16px var(--shadow);
            transform: translateY(-2px);
        }

        .card h2 {
            font-size: 1.3rem;
            margin-bottom: 20px;
            color: var(--accent);
            border-bottom: 2px solid var(--border);
            padding-bottom: 10px;
        }

        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid var(--border);
        }

        .info-row:last-child {
            border-bottom: none;
        }

        .label {
            font-weight: 600;
            color: var(--text-primary);
        }

        .value {
            color: var(--text-secondary);
            text-align: right;
        }

        .progress-bar {
            width: 100%;
            height: 20px;
            background: var(--progress-bg);
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0 5px 0;
        }

        .progress-fill {
            height: 100%;
            background: var(--progress-fill);
            transition: width 0.3s ease;
        }

        .progress-label {
            text-align: center;
            font-size: 0.85rem;
            color: var(--text-secondary);
            margin-bottom: 10px;
        }

        .storage-item {
            margin-bottom: 20px;
            padding: 15px;
            background: var(--bg-primary);
            border-radius: 8px;
        }

        .storage-item:last-child {
            margin-bottom: 0;
        }

        .health-good { color: var(--health-good) !important; font-weight: 600; }
        .health-warning { color: var(--health-warning) !important; font-weight: 600; }
        .health-unknown { color: var(--health-unknown) !important; }

        @media (max-width: 768px) {
            .dashboard {
                grid-template-columns: 1fr;
            }
            h1 {
                font-size: 2rem;
            }
        }
    </style>
</head>
<body data-theme="light">
    <div class="container">
        <header>
            <h1>💻 Computer Specifications</h1>
            <div class="header-info">
                <div class="timestamp">Generated: $timestamp</div>
                <div class="theme-toggle" id="themeToggle">
                    <span id="themeIcon">🌙</span>
                    <span id="themeText">Dark Mode</span>
                </div>
            </div>
        </header>

        <div class="dashboard">
            <!-- CPU Card -->
            <div class="card">
                <h2>🖥️ CPU</h2>
                <div class="info-row">
                    <span class="label">Model</span>
                    <span class="value">$($cpu.Name)</span>
                </div>
                <div class="info-row">
                    <span class="label">Cores</span>
                    <span class="value">$($cpu.Cores)</span>
                </div>
                <div class="info-row">
                    <span class="label">Logical Processors</span>
                    <span class="value">$($cpu.LogicalProcessors)</span>
                </div>
                <div class="info-row">
                    <span class="label">Clock Speed</span>
                    <span class="value">$($cpu.ClockSpeed)</span>
                </div>
                <div class="info-row">
                    <span class="label">Architecture</span>
                    <span class="value">$($cpu.Architecture)</span>
                </div>
            </div>

            <!-- RAM Card -->
            <div class="card">
                <h2>🧠 Memory (RAM)</h2>
                <div class="info-row">
                    <span class="label">Total</span>
                    <span class="value">$($ram.Total)</span>
                </div>
                <div class="info-row">
                    <span class="label">Used</span>
                    <span class="value">$($ram.Used)</span>
                </div>
                <div class="info-row">
                    <span class="label">Available</span>
                    <span class="value">$($ram.Available)</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($ram.UsagePercent)%"></div>
                </div>
                <div class="progress-label">$($ram.UsagePercent)% Used</div>
            </div>

            <!-- GPU Card -->
            <div class="card">
                <h2>🎮 Graphics (GPU)</h2>
$gpuCardsHtml
            </div>

            <!-- Motherboard Card -->
            <div class="card">
                <h2>⚙️ Motherboard</h2>
                <div class="info-row">
                    <span class="label">Manufacturer</span>
                    <span class="value">$($motherboard.Manufacturer)</span>
                </div>
                <div class="info-row">
                    <span class="label">Model</span>
                    <span class="value">$($motherboard.Model)</span>
                </div>
                <div class="info-row">
                    <span class="label">Max Memory</span>
                    <span class="value">$($motherboard.MaxMemoryCapacity)</span>
                </div>
            </div>

            <!-- Storage Card -->
            <div class="card">
                <h2>💾 Storage Drives</h2>
$storageCardsHtml
            </div>

            <!-- Boot Time Card -->
            <div class="card">
                <h2>⏱️ System Info</h2>
                <div class="info-row">
                    <span class="label">Last Boot Time</span>
                    <span class="value">$($boot.LastBootTime)</span>
                </div>
                <div class="info-row">
                    <span class="label">Uptime</span>
                    <span class="value">$($boot.Uptime)</span>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Theme toggle functionality
        const themeToggle = document.getElementById('themeToggle');
        const body = document.body;
        const themeIcon = document.getElementById('themeIcon');
        const themeText = document.getElementById('themeText');

        // Load saved theme or default to light
        const savedTheme = localStorage.getItem('theme') || 'light';
        body.setAttribute('data-theme', savedTheme);
        updateThemeUI(savedTheme);

        themeToggle.addEventListener('click', () => {
            const currentTheme = body.getAttribute('data-theme');
            const newTheme = currentTheme === 'light' ? 'dark' : 'light';
            body.setAttribute('data-theme', newTheme);
            localStorage.setItem('theme', newTheme);
            updateThemeUI(newTheme);
        });

        function updateThemeUI(theme) {
            if (theme === 'dark') {
                themeIcon.textContent = '☀️';
                themeText.textContent = 'Light Mode';
            } else {
                themeIcon.textContent = '🌙';
                themeText.textContent = 'Dark Mode';
            }
        }
    </script>
</body>
</html>
"@

# Save and open HTML file
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$fileName = "computer-specs-$fileTimestamp.html"
$outputPath = Join-Path $scriptPath $fileName

try {
    $html | Out-File -FilePath $outputPath -Encoding UTF8 -ErrorAction Stop
    Write-Host "Report generated: $outputPath" -ForegroundColor Green

    # Open in default browser
    Start-Process $outputPath
    Write-Host "Opening in default browser..." -ForegroundColor Green
} catch {
    Write-Error "Failed to create or open HTML file: $_"
}
