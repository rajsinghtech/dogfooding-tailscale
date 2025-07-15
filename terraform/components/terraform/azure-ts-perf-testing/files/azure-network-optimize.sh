#!/bin/bash

# Azure VM Network Optimization Script
# Based on Microsoft's recommendations for Linux VMs in Azure
# https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-optimize-network-bandwidth

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Warning function
warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Error function
error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Info function
info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root"
    fi
}

# Verify this is an Azure VM
check_azure_vm() {
    if ! curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" &> /dev/null; then
        warn "This does not appear to be an Azure VM. Some optimizations may not be applicable."
        return 1
    fi
    return 0
}

# Check kernel version
check_kernel_version() {
    local kernel_version
    kernel_version=$(uname -r | cut -d. -f1-2)
    local major_version
    major_version=$(echo "$kernel_version" | cut -d. -f1)
    local minor_version
    minor_version=$(echo "$kernel_version" | cut -d. -f2)
    
    if [ "$major_version" -lt 4 ] || { [ "$major_version" -eq 4 ] && [ "$minor_version" -lt 18 ]; }; then
        warn "Kernel version is $kernel_version. For best performance, use kernel 4.18 or later."
        return 1
    fi
    
    log "Kernel version $kernel_version is supported for optimal performance."
    return 0
}

# Create backup directory
create_backup() {
    local backup_dir="/etc/network/optimization_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup sysctl.conf and sysctl.d files
    cp -f /etc/sysctl.conf "${backup_dir}/sysctl.conf.bak" 2>/dev/null || true
    
    # Backup udev rules
    mkdir -p "${backup_dir}/udev/rules.d"
    cp -f /etc/udev/rules.d/*-net-*.rules "${backup_dir}/udev/rules.d/" 2>/dev/null || true
    
    log "Backup created at $backup_dir"
}

# Configure kernel parameters for network buffers
configure_network_buffers() {
    log "Configuring network buffer sizes..."
    
    # Create the Azure network buffers configuration file as per Microsoft documentation
    cat > /etc/sysctl.d/99-azure-network-buffers.conf << 'EOF'
# Azure VM Network Buffer Optimizations
# https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-optimize-network-bandwidth

net.core.rmem_default = 33554432
net.core.wmem_default = 33554432
net.core.wmem_max = 134217728
net.core.rmem_max = 134217728
net.core.busy_poll = 50
net.core.busy_read = 50
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_budget = 1000
net.core.optmem_max = 65535
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.core.dev_weight = 64
net.core.default_qdisc = fq
EOF
    
    # Additional TCP parameters to /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog = 8192" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_max_tw_buckets = 1440000" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_tw_reuse = 1" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_fin_timeout = 30" | tee -a /etc/sysctl.conf
    
    log "Network buffer configuration complete."
}

# Configure congestion control
configure_congestion_control() {
    log "Configuring TCP congestion control..."
    
    # Load BBR module if available (settings are in 99-azure-network-buffers.conf)
    if modprobe tcp_bbr 2>/dev/null; then
        echo "tcp_bbr" | tee -a /etc/modules-load.d/bbr.conf
        log "BBR congestion control module loaded."
    else
        warn "BBR congestion control module not available."
    fi
    
    
    log "Congestion control configuration complete."
}

# Configure additional TCP parameters
configure_tcp_extras() {
    log "Configuring additional TCP parameters..."
    
    # Increase the local port range
    echo "net.ipv4.ip_local_port_range = 2000 65535" | tee -a /etc/sysctl.conf
    
    # File system parameters
    echo "fs.file-max = 2000000" | tee -a /etc/sysctl.conf
    echo "fs.nr_open = 1000000" | tee -a /etc/sysctl.conf
    
    # Increase the maximum number of inotify watches
    echo "fs.inotify.max_user_watches = 1000000" | tee -a /etc/sysctl.conf
    echo "fs.inotify.max_user_instances = 65536" | tee -a /etc/sysctl.conf
    echo "fs.inotify.max_queued_events = 16384" | tee -a /etc/sysctl.conf
    
    # VM parameters
    echo "vm.max_map_count = 262144" | tee -a /etc/sysctl.conf
    echo "vm.vfs_cache_pressure = 50" | tee -a /etc/sysctl.conf
    
    log "Additional TCP parameters configured."
}

# Create udev rule for ring buffers
configure_ring_buffers() {
    log "Configuring network ring buffers..."
    
    # Create udev rule for ring buffers (1024 as per Microsoft documentation)
    cat > /etc/udev/rules.d/99-net-buffers.rules << 'UDEV_EOF'
# Set ring buffer sizes for all network interfaces
# Microsoft recommends 1024 for both RX and TX
ACTION=="add|change", SUBSYSTEM=="net", KERNEL=="eth*", \
    RUN+="/sbin/ethtool -G $name rx 1024 tx 1024"
UDEV_EOF
    
    log "Network ring buffer configuration complete."
}

# Create udev rule for queue discipline
configure_qdisc() {
    log "Configuring queue discipline..."
    
    # Create udev rule for queue discipline
    cat > /etc/udev/rules.d/99-net-qdisc.rules << 'QDISC_EOF'
# Set fq_codel as the default qdisc for all interfaces
ACTION=="add|change", SUBSYSTEM=="net", KERNEL=="eth*", \
    RUN+="/sbin/tc qdisc add dev $name root fq"
QDISC_EOF
    
    log "Queue discipline configuration complete."
}

# Create udev rule for transmit queue length
configure_txqueue_len() {
    log "Configuring transmit queue length..."
    
    # Create udev rule for transmit queue length
    cat > /etc/udev/rules.d/99-net-txqueuelen.rules << 'TXQUEUE_EOF'
# Set txqueuelen to 10000 for all interfaces
ACTION=="add|change", SUBSYSTEM=="net", KERNEL=="eth*", \
    RUN+="/sbin/ip link set dev $name txqueuelen 10000"
TXQUEUE_EOF
    
    log "Transmit queue length configuration complete."
}

# Apply sysctl parameters
apply_sysctl() {
    log "Applying sysctl parameters..."
    
    # Apply sysctl settings from both locations
    if ! sysctl -p /etc/sysctl.conf; then
        warn "Failed to apply sysctl.conf parameters."
    fi
    
    if ! sysctl -p /etc/sysctl.d/99-azure-network-buffers.conf; then
        warn "Failed to apply Azure network buffer parameters."
        return 1
    fi
    
    log "Sysctl parameters applied successfully."
    return 0
}

# Apply udev rules
apply_udev_rules() {
    log "Applying udev rules..."
    
    # Reload udev rules
    if ! udevadm control --reload-rules; then
        warn "Failed to reload udev rules. Some settings may not take effect until reboot."
        return 1
    fi
    
    # Trigger udev rules
    udevadm trigger
    
    log "Udev rules applied successfully."
    return 0
}

# Verify configuration
verify_configuration() {
    log "Verifying configuration..."
    local success=true
    
    # Verify sysctl parameters
    local params=(
        "net.core.rmem_max"
        "net.core.wmem_max"
        "net.core.rmem_default"
        "net.core.wmem_default"
        "net.core.busy_poll"
        "net.core.busy_read"
        "net.core.netdev_budget"
        "net.core.optmem_max"
        "net.core.somaxconn"
        "net.core.netdev_max_backlog"
        "net.ipv4.tcp_congestion_control"
        "net.core.default_qdisc"
    )
    
    for param in "${params[@]}"; do
        if ! sysctl "$param" &>/dev/null; then
            warn "Failed to verify parameter: $param"
            success=false
        fi
    done
    
    # Verify udev rules
    if [ ! -f "/etc/udev/rules.d/99-net-buffers.rules" ] || 
       [ ! -f "/etc/udev/rules.d/99-net-qdisc.rules" ] || 
       [ ! -f "/etc/udev/rules.d/99-net-txqueuelen.rules" ]; then
        warn "One or more udev rule files are missing."
        success=false
    fi
    
    if $success; then
        log "Configuration verification successful."
        return 0
    else
        warn "Some configuration verifications failed. See above for details."
        return 1
    fi
}

# Main execution
main() {
    log "Starting Azure network optimization..."
    
    # Check if running as root
    check_root
    
    # Verify this is an Azure VM (warning only, don't fail)
    check_azure_vm || true
    
    # Check kernel version (warning only, don't fail)
    check_kernel_version || true
    
    # Create backup of current configuration
    create_backup
    
    # Configure network buffers
    configure_network_buffers
    
    # Configure congestion control
    configure_congestion_control
    
    # Configure additional TCP parameters
    configure_tcp_extras
    
    # Configure ring buffers
    configure_ring_buffers
    
    # Configure queue discipline
    configure_qdisc
    
    # Configure transmit queue length
    configure_txqueue_len
    
    # Apply sysctl parameters
    apply_sysctl || true
    
    # Apply udev rules
    apply_udev_rules || true
    
    # Verify configuration
    verify_configuration || true
    
    log "Network optimization complete. Some changes may require a reboot to take effect."
    log "To apply all changes immediately, run: reboot"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
