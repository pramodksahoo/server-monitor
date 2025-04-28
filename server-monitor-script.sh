#!/bin/bash

# Advanced Server Monitoring Script
# Purpose: Monitor and display key system metrics for server health analysis
# Version: 2.1

# ======================== CONFIGURATION ========================
# Thresholds for warnings (values in %)
CPU_WARNING_THRESHOLD=70
CPU_CRITICAL_THRESHOLD=90
MEM_WARNING_THRESHOLD=70
MEM_CRITICAL_THRESHOLD=90
DISK_WARNING_THRESHOLD=70
DISK_CRITICAL_THRESHOLD=90
SWAP_WARNING_THRESHOLD=30
NET_BW_WARNING=1000000  # 1 MB/s

# Default refresh interval in seconds (only used when running in real-time mode)
REFRESH_INTERVAL=5

# ======================== COLORS & FORMATTING ========================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[1;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
RESET='\033[0m'

# ======================== HELPER FUNCTIONS ========================
separator="========================================================================"

print_header() {
    echo -e "\n${CYAN}${BOLD}$1${RESET}"
    echo "$separator"
}

# Function to format size values with appropriate units
format_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then 
        echo "$(awk -v size=$size 'BEGIN { printf("%.2f", size/1073741824) }') GB"
    elif [ $size -ge 1048576 ]; then
        echo "$(awk -v size=$size 'BEGIN { printf("%.2f", size/1048576) }') MB"
    elif [ $size -ge 1024 ]; then
        echo "$(awk -v size=$size 'BEGIN { printf("%.2f", size/1024) }') KB"
    else
        echo "$size B"
    fi
}

# Function to compare values with awk instead of bc
compare_values() {
    local value=$1
    local compare=$2
    awk -v val="$value" -v comp="$compare" 'BEGIN { if (val > comp) print 1; else print 0 }'
}

# Function to print status with appropriate color based on thresholds
print_status() {
    local metric=$1
    local warning_threshold=$2
    local critical_threshold=$3
    local format=$4
    
    if [ "$(compare_values $metric $critical_threshold)" -eq 1 ]; then
        echo -e "$format${RED}${metric}%${RESET}${format:+\)}"
    elif [ "$(compare_values $metric $warning_threshold)" -eq 1 ]; then
        echo -e "$format${YELLOW}${metric}%${RESET}${format:+\)}"
    else
        echo -e "$format${GREEN}${metric}%${RESET}${format:+\)}"
    fi
}

# Function to show a simple progress bar
progress_bar() {
    local percent=$1
    local width=40
    local filled=$(awk -v p="$percent" -v w="$width" 'BEGIN { printf("%d", p * w / 100) }')
    local empty=$((width - filled))
    
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] "
}

# Function to print help
show_help() {
    echo -e "${BOLD}Advanced Server Monitoring Script${RESET}"
    echo -e "Usage: $0 [OPTIONS]"
    echo -e "\nOptions:"
    echo -e "  -r, --realtime        Run in real-time monitoring mode with periodic refresh"
    echo -e "  -i, --interval <sec>  Set refresh interval for real-time mode (default: $REFRESH_INTERVAL sec)"
    echo -e "  -f, --file <path>     Save output to the specified file"
    echo -e "  -d, --detail          Show detailed system information"
    echo -e "  -n, --network         Show detailed network statistics"
    echo -e "  -l, --log <lines>     Show last specified lines from system log"
    echo -e "  -h, --help            Display this help message"
    echo -e "\nExample: $0 --realtime --interval 10 --file server-status.log"
}

# ======================== COMMAND LINE ARGUMENTS PARSING ========================
REALTIME_MODE=false
DETAIL_MODE=false
NETWORK_MODE=false
OUTPUT_FILE=""
LOG_LINES=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--realtime) REALTIME_MODE=true ;;
        -i|--interval) REFRESH_INTERVAL="$2"; shift ;;
        -f|--file) OUTPUT_FILE="$2"; shift ;;
        -d|--detail) DETAIL_MODE=true ;;
        -n|--network) NETWORK_MODE=true ;;
        -l|--log) LOG_LINES="$2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
    esac
    shift
done

# ======================== MONITORING FUNCTIONS ========================
monitor_hostname_info() {
    print_header "🖥️  System Information"
    hostname=$(hostname)
    kernel=$(uname -r)
    uptime=$(uptime -p)
    uptime_seconds=$(awk '{print $1}' /proc/uptime)
    uptime_days=$(awk -v sec="$uptime_seconds" 'BEGIN {printf "%d", sec/86400}')
    last_boot=$(who -b | awk '{print $3, $4}')
    users_logged=$(who | wc -l)
    
    printf "Hostname      : ${YELLOW}${hostname}${RESET}\n"
    printf "Kernel        : ${YELLOW}${kernel}${RESET}\n"
    printf "Uptime        : ${YELLOW}${uptime} (${uptime_days} days)${RESET}\n"
    printf "Last Boot     : ${YELLOW}${last_boot}${RESET}\n"
    printf "Users Logged  : ${YELLOW}${users_logged}${RESET}\n"
    
    # Show distribution info if available
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        printf "Distribution  : ${YELLOW}${PRETTY_NAME}${RESET}\n"
    fi
}

monitor_cpu() {
    print_header "🔄 CPU Usage"
    
    # Get CPU stats
    top_output=$(top -bn1)
    cpu_idle=$(echo "$top_output" | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/')
    cpu_usage=$(awk -v idle="$cpu_idle" 'BEGIN { printf("%.1f", 100 - idle) }')
    
    # Number of CPU cores
    cpu_cores=$(grep -c ^processor /proc/cpuinfo)
    cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d ":" -f2 | sed 's/^[ \t]*//')
    
    # CPU frequency
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
        cpu_freq_ghz=$(awk -v freq="$cpu_freq" 'BEGIN { printf("%.2f", freq/1000000) }')
        cpu_freq_display="${cpu_freq_ghz} GHz"
    else
        cpu_freq_display="N/A"
    fi
    
    # CPU load averages
    read load1 load5 load15 <<< $(awk '{print $1,$2,$3}' /proc/loadavg)
    
    printf "CPU Model     : ${YELLOW}${cpu_model}${RESET}\n"
    printf "CPU Cores     : ${YELLOW}${cpu_cores}${RESET}\n"
    printf "CPU Frequency : ${YELLOW}${cpu_freq_display}${RESET}\n"
    
    printf "Current Usage : "
    progress_bar $cpu_usage
    print_status $cpu_usage $CPU_WARNING_THRESHOLD $CPU_CRITICAL_THRESHOLD
    
    printf "Load Average  : ${YELLOW}${load1} (1m), ${load5} (5m), ${load15} (15m)${RESET}\n"
    
    # Detailed CPU stats if detail mode enabled
    if $DETAIL_MODE; then
        echo
        echo "CPU Usage by Core:"
        mpstat -P ALL 1 1 | awk '/^[0-9]/ && !/CPU/ {printf "Core %2d: %s%5.1f%%%s\n", $3, $13>30?$13>70?"\033[0;31m":"\033[1;33m":"\033[0;32m", 100-$13, "\033[0m"}'
    fi
}

monitor_memory() {
    print_header "🧠 Memory Usage"
    
    # Memory stats
    read total_memory available_memory <<< $(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print t, a}' /proc/meminfo)
    used_memory=$((total_memory - available_memory))
    
    # Calculate percentages
    used_memory_percent=$(awk -v u=$used_memory -v t=$total_memory 'BEGIN { printf("%.1f", (u / t) * 100) }')
    available_memory_percent=$(awk -v a=$available_memory -v t=$total_memory 'BEGIN { printf("%.1f", (a / t) * 100) }')
    
    # Convert from kB to more readable format
    total_memory_human=$(format_size ${total_memory}000)
    used_memory_human=$(format_size ${used_memory}000)
    available_memory_human=$(format_size ${available_memory}000)
    
    printf "Total Memory  : ${YELLOW}${total_memory_human}${RESET}\n"
    
    printf "Used Memory   : "
    progress_bar $used_memory_percent
    print_status $used_memory_percent $MEM_WARNING_THRESHOLD $MEM_CRITICAL_THRESHOLD " (${used_memory_human}, "
    
    printf "Free Memory   : "
    progress_bar $available_memory_percent
    printf "${GREEN}${available_memory_percent}%%${RESET} (${available_memory_human})\n"
    
    # SWAP usage
    if grep -q "SwapTotal" /proc/meminfo; then
        swap_total=$(grep "SwapTotal" /proc/meminfo | awk '{print $2}')
        
        if [ "$swap_total" -gt 0 ]; then
            swap_free=$(grep "SwapFree" /proc/meminfo | awk '{print $2}')
            swap_used=$((swap_total - swap_free))
            swap_percent=$(awk -v u=$swap_used -v t=$swap_total 'BEGIN { printf("%.1f", (u / t) * 100) }')
            
            # Convert from kB to more readable format
            swap_total_human=$(format_size ${swap_total}000)
            swap_used_human=$(format_size ${swap_used}000)
            
            echo
            printf "Swap Total    : ${YELLOW}${swap_total_human}${RESET}\n"
            printf "Swap Used     : "
            progress_bar $swap_percent
            
            if [ "$(compare_values $swap_percent $SWAP_WARNING_THRESHOLD)" -eq 1 ]; then
                echo -e "${YELLOW}${swap_percent}%${RESET} (${swap_used_human})"
            else
                echo -e "${GREEN}${swap_percent}%${RESET} (${swap_used_human})"
            fi
        else
            echo
            echo "Swap Memory   : Not configured"
        fi
    fi
}

monitor_disk() {
    print_header "💾 Disk Usage"
    
    # Get mount points - filter out containerization stuff to reduce clutter
    mount_points=$(df -h | grep -v "tmpfs\|udev\|loop\|containerd\|overlay" | awk 'NR>1 {print $6}')
    
    # Display header
    printf "%-15s %-8s %-8s %-8s %-6s %s\n" "Mount Point" "Size" "Used" "Avail" "Use%" "Type"
    printf "%-15s %-8s %-8s %-8s %-6s %s\n" "------------" "----" "----" "-----" "----" "----"
    
    # Process each mount point
    for mount in $mount_points; do
        df_output=$(df -h $mount)
        df_output_raw=$(df $mount)
        
        fs_type=$(mount | grep " $mount " | awk '{for(i=1;i<=NF;i++) if($i=="type") print $(i+1)}')
        
        read size_disk used_disk available_disk used_percent <<< $(echo "$df_output" | awk 'NR==2 {print $2, $3, $4, $5}')
        used_percent_num=$(echo $used_percent | tr -d '%')
        
        # Color the usage percentage based on thresholds
        if [ "$(compare_values $used_percent_num $DISK_CRITICAL_THRESHOLD)" -eq 1 ]; then
            format="${RED}"
        elif [ "$(compare_values $used_percent_num $DISK_WARNING_THRESHOLD)" -eq 1 ]; then
            format="${YELLOW}"
        else
            format="${GREEN}"
        fi
        
        printf "%-15s %-8s %-8s %-8s ${format}%-6s${RESET} %s\n" \
            "$mount" "$size_disk" "$used_disk" "$available_disk" "$used_percent" "$fs_type"
    done
    
    if $DETAIL_MODE; then
        echo
        echo "Disk I/O Statistics:"
        iostat -d -x 2>/dev/null | grep -v "loop\|ram" | grep -A 100 "Device" | head -n 10 || echo "iostat not available (install sysstat package)"
    fi
}

monitor_network() {
    print_header "🌐 Network Status"
    
    # Get default route interface
    default_iface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # If no default interface found, use the first interface
    if [ -z "$default_iface" ]; then
        default_iface=$(ip link show | grep -v "lo:" | grep "state UP" | head -1 | cut -d: -f2 | awk '{print $1}')
    fi
    
    # Get IP addresses
    ipv4_addr=$(ip -4 addr show $default_iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    ipv6_addr=$(ip -6 addr show $default_iface 2>/dev/null | grep -oP '(?<=inet6\s)[0-9a-f:]+' | head -1)
    
    # Get network statistics
    rx_bytes_old=$(cat /proc/net/dev | grep $default_iface | awk '{print $2}')
    tx_bytes_old=$(cat /proc/net/dev | grep $default_iface | awk '{print $10}')
    
    # Sleep briefly to calculate bandwidth
    sleep 1
    
    rx_bytes_new=$(cat /proc/net/dev | grep $default_iface | awk '{print $2}')
    tx_bytes_new=$(cat /proc/net/dev | grep $default_iface | awk '{print $10}')
    
    rx_bps=$((rx_bytes_new - rx_bytes_old))
    tx_bps=$((tx_bytes_new - tx_bytes_old))
    
    # Format RX/TX rates
    rx_rate=$(format_size $rx_bps)
    tx_rate=$(format_size $tx_bps)
    
    # MAC address
    mac_address=$(ip link show $default_iface | grep "link/ether" | awk '{print $2}')
    
    # Network interface status
    interface_status=$(ip link show $default_iface | grep -oP 'state \K\w+')
    
    printf "Interface     : ${YELLOW}${default_iface}${RESET}\n"
    printf "Status        : ${interface_status} ${RESET}\n"
    printf "IPv4 Address  : ${YELLOW}${ipv4_addr:-None}${RESET}\n"
    printf "IPv6 Address  : ${YELLOW}${ipv6_addr:-None}${RESET}\n"
    printf "MAC Address   : ${YELLOW}${mac_address}${RESET}\n"
    printf "RX Rate       : ${YELLOW}${rx_rate}/s${RESET}\n"
    printf "TX Rate       : ${YELLOW}${tx_rate}/s${RESET}\n"
    
    # Get connection information
    if $NETWORK_MODE; then
        echo
        echo "Active Connections:"
        printf "%-5s %-20s %-20s %-12s\n" "Proto" "Local Address" "Foreign Address" "State"
        printf "%-5s %-20s %-20s %-12s\n" "-----" "-------------" "---------------" "-----"
        
        # Try netstat first, then ss if netstat is not available
        if command -v netstat &> /dev/null; then
            # Show top 10 connections
            netstat -tn 2>/dev/null | grep -v "servers\|addresses" | head -10 | while read line; do
                proto=$(echo $line | awk '{print $1}')
                local=$(echo $line | awk '{print $4}')
                foreign=$(echo $line | awk '{print $5}')
                state=$(echo $line | awk '{print $6}')
                
                printf "%-5s %-20s %-20s %-12s\n" "$proto" "$local" "$foreign" "$state"
            done
        elif command -v ss &> /dev/null; then
            ss -tn | grep -v "State" | head -10 | while read line; do
                proto=$(echo $line | awk '{print $1}')
                state=$(echo $line | awk '{print $2}')
                local=$(echo $line | awk '{print $4}')
                foreign=$(echo $line | awk '{print $5}')
                
                printf "%-5s %-20s %-20s %-12s\n" "$proto" "$local" "$foreign" "$state"
            done
        else
            echo "Network connection tools (netstat/ss) not available"
        fi
        
        echo
        echo "Listening Ports:"
        if command -v ss &> /dev/null; then
            ss -tuln | grep LISTEN | awk '{printf "%-5s %-20s\n", $1, $5}'
        elif command -v netstat &> /dev/null; then
            netstat -tuln | grep LISTEN | awk '{printf "%-5s %-20s\n", $1, $4}'
        else
            echo "Network tools not available"
        fi
    fi
}

monitor_processes() {
    print_header "🔄 Process Information"
    
    # Get process counts
    total_procs=$(ps aux | wc -l)
    running_procs=$(ps r | wc -l)
    zombie_procs=$(ps aux | grep -c Z)
    
    printf "Total Processes      : ${YELLOW}${total_procs}${RESET}\n"
    printf "Running Processes    : ${YELLOW}${running_procs}${RESET}\n"
    printf "Zombie Processes     : ${YELLOW}${zombie_procs}${RESET}\n"
    
    # Top processes by CPU
    echo
    echo -e "${BOLD}Top 5 Processes by CPU${RESET}"
    printf "%-10s %-6s %-7s %-7s %-9s %s\n" "USER" "PID" "%CPU" "%MEM" "TIME" "COMMAND"
    ps aux --sort=-%cpu | head -6 | tail -5 2>/dev/null | awk '{printf "%-10s %-6s %-7s %-7s %-9s %s\n", $1, $2, $3, $4, $10, $11}'
    
    # Top processes by memory
    echo
    echo -e "${BOLD}Top 5 Processes by Memory${RESET}"
    printf "%-10s %-6s %-7s %-7s %-9s %s\n" "USER" "PID" "%CPU" "%MEM" "TIME" "COMMAND"
    ps aux --sort=-%mem | head -6 | tail -5 2>/dev/null | awk '{printf "%-10s %-6s %-7s %-7s %-9s %s\n", $1, $2, $3, $4, $10, $11}'
}

monitor_system_logs() {
    if [ "$LOG_LINES" -gt 0 ]; then
        print_header "📋 Recent System Logs"
        
        echo -e "${BOLD}Last $LOG_LINES Lines from System Log:${RESET}"
        
        # Try different log files based on distribution
        if [ -f /var/log/syslog ] && [ -r /var/log/syslog ]; then
            # Debian/Ubuntu
            tail -n $LOG_LINES /var/log/syslog | grep -v -E "^$" | sed -e "s/.*error.*/$(tput setaf 1)&$(tput sgr0)/" -e "s/.*fail.*/$(tput setaf 1)&$(tput sgr0)/" -e "s/.*warn.*/$(tput setaf 3)&$(tput sgr0)/"
        elif [ -f /var/log/messages ] && [ -r /var/log/messages ]; then
            # RHEL/CentOS
            tail -n $LOG_LINES /var/log/messages | grep -v -E "^$" | sed -e "s/.*error.*/$(tput setaf 1)&$(tput sgr0)/" -e "s/.*fail.*/$(tput setaf 1)&$(tput sgr0)/" -e "s/.*warn.*/$(tput setaf 3)&$(tput sgr0)/"
        else
            # Try journalctl as a fallback
            if command -v journalctl &> /dev/null; then
                journalctl -n $LOG_LINES | grep -v -E "^$" | sed -e "s/.*error.*/$(tput setaf 1)&$(tput sgr0)/" -e "s/.*fail.*/$(tput setaf 1)&$(tput sgr0)/" -e "s/.*warn.*/$(tput setaf 3)&$(tput sgr0)/"
            else
                echo "System log files not found or not readable"
            fi
        fi
    fi
}

monitor_security() {
    print_header "🔒 Security Information"
    
    # Failed login attempts
    if [ -f /var/log/auth.log ] && [ -r /var/log/auth.log ]; then
        failed_logins=$(grep -i "failed password" /var/log/auth.log 2>/dev/null | wc -l)
        last_failed=$(grep -i "failed password" /var/log/auth.log 2>/dev/null | tail -1)
    elif [ -f /var/log/secure ] && [ -r /var/log/secure ]; then
        failed_logins=$(grep -i "failed password" /var/log/secure 2>/dev/null | wc -l)
        last_failed=$(grep -i "failed password" /var/log/secure 2>/dev/null | tail -1)
    else
        failed_logins="N/A"
        last_failed="N/A"
    fi
    
    # Last logins
    if command -v last &> /dev/null; then
        last_successful=$(last -n 5 2>/dev/null | grep -v "reboot" | head -1)
    else
        last_successful="N/A"
    fi
    
    printf "Failed Login Attempts: ${YELLOW}${failed_logins}${RESET}\n"
    
    if [ "$last_failed" != "N/A" ] && [ ! -z "$last_failed" ]; then
        printf "Last Failed Attempt  : ${YELLOW}${last_failed}${RESET}\n"
    fi
    
    if [ "$last_successful" != "N/A" ] && [ ! -z "$last_successful" ]; then
        printf "Last Login           : ${YELLOW}${last_successful}${RESET}\n"
    fi
    
    # Check for running SSH
    if command -v systemctl &> /dev/null; then
        ssh_status=$(systemctl is-active sshd 2>/dev/null || echo "inactive")
    elif command -v service &> /dev/null; then
        ssh_status=$(service sshd status 2>/dev/null | grep -o "running" || echo "stopped")
    else
        ssh_status="Unknown"
    fi
    printf "SSH Service Status   : ${YELLOW}${ssh_status}${RESET}\n"
    
    # Check for firewall
    if command -v ufw &> /dev/null; then
        firewall_status=$(ufw status | head -1)
        printf "Firewall Status      : ${YELLOW}${firewall_status}${RESET}\n"
    elif command -v firewall-cmd &> /dev/null; then
        firewall_status=$(firewall-cmd --state 2>/dev/null || echo "Not running")
        printf "Firewall Status      : ${YELLOW}${firewall_status}${RESET}\n"
    elif command -v iptables &> /dev/null; then
        # Check if iptables has any rules
        rules_count=$(iptables -L -n | grep -c "^Chain")
        if [ "$rules_count" -gt 0 ]; then
            printf "Firewall Status      : ${YELLOW}iptables active ($rules_count chains)${RESET}\n"
        else
            printf "Firewall Status      : ${YELLOW}iptables inactive${RESET}\n"
        fi
    else
        printf "Firewall Status      : ${YELLOW}Unknown${RESET}\n"
    fi
}

# ======================== MAIN EXECUTION ========================
display_system_info() {
    # Clear screen in real-time mode
    if $REALTIME_MODE; then
        clear
        echo -e "${BOLD}${BLUE}==== Advanced Server Monitor ==== $(date) ====${RESET}"
    fi
    
    monitor_hostname_info
    monitor_cpu
    monitor_memory
    monitor_disk
    monitor_network
    monitor_processes
    
    if [ "$LOG_LINES" -gt 0 ]; then
        monitor_system_logs
    fi
    
    monitor_security
    
    # Print summary with timestamp
    print_header "📊 System Health Summary"
    current_time=$(date +"%Y-%m-%d %H:%M:%S")
    printf "Report Time : ${YELLOW}${current_time}${RESET}\n"
    
    # Simple health status summary based on thresholds
    cpu_health="OK"
    mem_health="OK"
    disk_health="OK"
    
    if [ "$(compare_values $cpu_usage $CPU_CRITICAL_THRESHOLD)" -eq 1 ]; then
        cpu_health="${RED}CRITICAL${RESET}"
    elif [ "$(compare_values $cpu_usage $CPU_WARNING_THRESHOLD)" -eq 1 ]; then
        cpu_health="${YELLOW}WARNING${RESET}"
    fi
    
    if [ "$(compare_values $used_memory_percent $MEM_CRITICAL_THRESHOLD)" -eq 1 ]; then
        mem_health="${RED}CRITICAL${RESET}"
    elif [ "$(compare_values $used_memory_percent $MEM_WARNING_THRESHOLD)" -eq 1 ]; then
        mem_health="${YELLOW}WARNING${RESET}"
    fi
    
    # Check if any disk is over threshold
    disk_health="${GREEN}OK${RESET}"
    for mount in $mount_points; do
        used_percent=$(df -h $mount | awk 'NR==2 {print $5}' | sed 's/%//')
        if [ "$(compare_values $used_percent $DISK_CRITICAL_THRESHOLD)" -eq 1 ]; then
            disk_health="${RED}CRITICAL${RESET}"
            break
        elif [ "$(compare_values $used_percent $DISK_WARNING_THRESHOLD)" -eq 1 ]; then
            disk_health="${YELLOW}WARNING${RESET}"
            break
        fi
    done
    
    printf "CPU Status  : ${cpu_health}\n"
    printf "Memory      : ${mem_health}\n"
    printf "Disk Space  : ${disk_health}\n"
    
    echo -e "\n${GRAY}Script executed by $(whoami)${RESET}"
}

# Execute in real-time mode if selected
if $REALTIME_MODE; then
    echo "Running in real-time mode with ${REFRESH_INTERVAL} second interval. Press Ctrl+C to exit."
    while true; do
        if [ -n "$OUTPUT_FILE" ]; then
            # Direct output to both file and screen
            display_system_info | tee "$OUTPUT_FILE"
        else
            display_system_info
        fi
        sleep $REFRESH_INTERVAL
    done
else
    # One-time execution
    if [ -n "$OUTPUT_FILE" ]; then
        display_system_info | tee "$OUTPUT_FILE"
    else
        display_system_info
    fi
fi
