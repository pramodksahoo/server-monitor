# Advanced Server Monitoring Script

![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-2.1-blue)
![Bash](https://img.shields.io/badge/bash-compatible-orange)

A comprehensive, feature-rich Bash script for real-time and on-demand server health monitoring with color-coded output.

## 📋 Overview

This advanced server monitoring script provides a detailed overview of system health metrics with colorized, easy-to-read output. It's designed to be lightweight yet comprehensive, offering both real-time monitoring and on-demand reporting capabilities without requiring additional dependencies beyond standard Linux utilities.

## ✨ Features

- **Comprehensive System Metrics**:
  - CPU usage and load averages
  - Memory and swap utilization with visual indicators
  - Disk usage across all mount points
  - Network traffic and interface information
  - Process statistics and top resource consumers
  - Security information including login attempts
  
- **Visual Feedback**:
  - Color-coded metrics based on configurable thresholds
  - Progress bars for usage percentages
  - Clean, organized output sections
  
- **Multiple Operating Modes**:
  - One-time status report
  - Real-time monitoring with configurable refresh intervals
  - Output capture to log files
  
- **Customizable Alerts**:
  - Configurable warning and critical thresholds
  - Visual indicators for metrics exceeding thresholds

## 🚀 Usage

### Basic Usage

Run the script for a one-time system status report:

```bash
./server-monitor-script.sh
```

### Command Line Options

```
Usage: ./server-monitor-script.sh [OPTIONS]

Options:
  -r, --realtime        Run in real-time monitoring mode with periodic refresh
  -i, --interval <sec>  Set refresh interval for real-time mode (default: 5 sec)
  -f, --file <path>     Save output to the specified file
  -d, --detail          Show detailed system information
  -n, --network         Show detailed network statistics
  -l, --log <lines>     Show last specified lines from system log
  -h, --help            Display this help message

Example: ./server-monitor-script.sh --realtime --interval 10 --file server-status.log
```

### Common Use Cases

**Real-time monitoring with 10-second refresh:**
```bash
./server-monitor-script.sh --realtime --interval 10
```

**Generate a report and save to file:**
```bash
./server-monitor-script.sh --file ~/server-report.log
```

**Show detailed information with system logs:**
```bash
./server-monitor-script.sh --detail --log 20
```

## 📋 Sample Output

```
==== Advanced Server Monitor ==== Wed Apr 28 09:15:27 EDT 2025 ====

🖥️  System Information
========================================================================
Hostname      : web-server-prod-01
Kernel        : 5.15.0-91-generic
Uptime        : up 42 days, 5 hours, 27 minutes (42 days)
Last Boot     : 2025-03-17 03:48
Users Logged  : 3
Distribution  : Ubuntu 22.04.3 LTS

🔄 CPU Usage
========================================================================
CPU Model     : Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz
CPU Cores     : 8
CPU Frequency : 2.40 GHz
Current Usage : [███████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 18.5%
Load Average  : 0.25 (1m), 0.31 (5m), 0.28 (15m)

... [other sections follow] ...
```

## ⚙️ Configuration

You can modify the threshold values at the top of the script to adjust warning and critical levels:

```bash
# Thresholds for warnings (values in %)
CPU_WARNING_THRESHOLD=70
CPU_CRITICAL_THRESHOLD=90
MEM_WARNING_THRESHOLD=70
MEM_CRITICAL_THRESHOLD=90
DISK_WARNING_THRESHOLD=70
DISK_CRITICAL_THRESHOLD=90
SWAP_WARNING_THRESHOLD=30
NET_BW_WARNING=1000000  # 1 MB/s
```

## 🔧 Requirements

- Bash shell
- Core Linux utilities (grep, awk, sed)
- Optional tools for enhanced functionality:
  - sysstat package for iostat/mpstat commands
  - net-tools or iproute2 for network monitoring

## 📝 License

This script is released under the MIT License. Feel free to modify and distribute it according to your needs.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📊 Planned Features

- Email notifications for threshold breaches
- Historical data collection and graphing
- Automatic service restart options
- Integration with monitoring platforms
