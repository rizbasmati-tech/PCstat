# PowerShell Computer Specs Dashboard

## Overview
PowerShell script that collects computer specs and displays them in an HTML dashboard.

## Data to Collect

**CPU**: Model, cores, clock speed, architecture
**RAM**: Total, available, used, usage %
**GPU**: Model(s), VRAM for each
**Motherboard**: Model, manufacturer, max memory capacity
**Storage (all drives)**: Model, capacity, used/free space, age via SMART data, health status
**Boot/Uptime**: Last boot time, system uptime

## Output

**File**: `computer-specs-YYYY-MM-DD_HH-MM-SS.html`
**Location**: Same directory as script
**Format**: Self-contained HTML with embedded CSS/JS
**Auto-open**: Opens in default browser after generation

## UI

**Layout**: Card-based dashboard
**Theme**: Light/dark toggle with localStorage persistence
**Design**: Responsive, progress bars for storage, professional styling

## Technical

**PowerShell**: 5.1+
**Data source**: WMI/CIM (`Get-CimInstance`)
**SMART data**: Via WMI (requires admin, graceful fallback if unavailable)
**Browser**: Opens with `Start-Process`
