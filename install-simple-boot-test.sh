#!/bin/bash
set -e

echo "=== Simple Boot Test Installer ==="
echo ""

# Configuration (user can change these)
DEFAULT_MAX_REBOOTS=10
DEFAULT_REBOOT_DELAY=30

# Get user input or use defaults
read -p "Enter number of reboots to test [$DEFAULT_MAX_REBOOTS]: " MAX_REBOOTS
MAX_REBOOTS=${MAX_REBOOTS:-$DEFAULT_MAX_REBOOTS}

read -p "Enter delay between reboots (seconds) [$DEFAULT_REBOOT_DELAY]: " REBOOT_DELAY
REBOOT_DELAY=${REBOOT_DELAY:-$DEFAULT_REBOOT_DELAY}

# 1. Create directories
echo "Creating directories..."
mkdir -p /root/log/boot-test

# 2. Create main script
echo "Creating main script..."
cat > /usr/local/bin/boot-test << 'SCRIPT'
#!/bin/bash
# Simple Boot Test Script
# Configurable via /etc/boot-test.conf

# Load configuration
CONFIG_FILE="/etc/boot-test.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Default values
    MAX_REBOOTS=10
    REBOOT_DELAY=30
fi

# Storage location
DATA_DIR="/root/log/boot-test"
COUNT_FILE="$DATA_DIR/count.txt"
LOG_FILE="$DATA_DIR/test.log"

# Ensure directory exists
mkdir -p "$DATA_DIR"

# Initialize if needed
[ -f "$COUNT_FILE" ] || echo "0" > "$COUNT_FILE"

# Read and update count
COUNT=$(cat "$COUNT_FILE")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

# Log this boot
echo "[$(date)] Boot #$COUNT" >> "$LOG_FILE"
echo "Uptime: $(uptime)" >> "$LOG_FILE"

# Display status
echo "=== Boot Test ==="
echo "Boot Count: $COUNT/$MAX_REBOOTS"
echo "Delay: $REBOOT_DELAY seconds"

# Check if test is complete
if [ $COUNT -ge $MAX_REBOOTS ]; then
    echo "✅ Test completed after $MAX_REBOOTS reboots!" | tee -a "$LOG_FILE"
    exit 0
fi

# Countdown to reboot
echo "Next reboot in $REBOOT_DELAY seconds..."
for i in $(seq $REBOOT_DELAY -1 1); do
    if [ $i -le 10 ] || [ $((i % 10)) -eq 0 ]; then
        echo "  $i seconds remaining..."
    fi
    sleep 1
done

echo "Rebooting now..."
/sbin/reboot
SCRIPT

chmod +x /usr/local/bin/boot-test

# 3. Create configuration file
echo "Creating configuration file..."
cat > /etc/boot-test.conf << CONFIG
# Boot Test Configuration
# Edit these values to change test behavior

MAX_REBOOTS=$MAX_REBOOTS      # Total number of reboots to test
REBOOT_DELAY=$REBOOT_DELAY    # Delay between reboots (seconds)
CONFIG

# 4. Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/boot-test.service << SERVICE
[Unit]
Description=Simple Boot Test
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/boot-test
Restart=no

[Install]
WantedBy=multi-user.target
SERVICE

# 5. Create control scripts
echo "Creating control scripts..."

# Status script
cat > /usr/local/bin/boot-status << STATUS
#!/bin/bash
echo "=== Boot Test Status ==="
echo "Time: $(date)"

if [ -f /root/log/boot-test/count.txt ]; then
    COUNT=$(cat /root/log/boot-test/count.txt)
    echo "Current Boot: $COUNT"
else
    echo "Test not started"
fi

if [ -f /etc/boot-test.conf ]; then
    echo ""
    echo "=== Configuration ==="
    grep -v "^#" /etc/boot-test.conf
fi

echo ""
echo "=== Last Log ==="
tail -2 /root/log/boot-test/test.log 2>/dev/null || echo "No logs"
STATUS

chmod +x /usr/local/bin/boot-status

# Stop script
cat > /usr/local/bin/boot-stop << STOP
#!/bin/bash
echo "Stopping boot test..."
systemctl stop boot-test
echo "Stopped"
STOP
chmod +x /usr/local/bin/boot-stop

# Start script
cat > /usr/local/bin/boot-start << START
#!/bin/bash
echo "Starting boot test..."
systemctl start boot-test
echo "Started"
START
chmod +x /usr/local/bin/boot-start

# Reset script
cat > /usr/local/bin/boot-reset << RESET
#!/bin/bash
echo "Resetting boot test..."
systemctl stop boot-test 2>/dev/null
echo "0" > /root/log/boot-test/count.txt
echo "Test reset"
RESET
chmod +x /usr/local/bin/boot-reset

# Config update script
cat > /usr/local/bin/boot-config << CONFIGSCRIPT
#!/bin/bash
echo "=== Boot Test Configuration ==="
echo "Current configuration:"
echo ""
cat /etc/boot-test.conf
echo ""
echo "To change configuration:"
echo "1. Edit /etc/boot-test.conf"
echo "2. Run: systemctl restart boot-test"
CONFIGSCRIPT
chmod +x /usr/local/bin/boot-config

# 6. Initialize
echo "Initializing..."
echo "0" > /root/log/boot-test/count.txt
touch /root/log/boot-test/test.log

# 7. Start service
echo "Starting service..."
systemctl daemon-reload
systemctl enable boot-test
systemctl start boot-test

# 8. Show completion
echo ""
echo "✅ Installation Complete!"
echo ""
echo "=== Quick Commands ==="
echo "boot-status      - Check current status"
echo "boot-stop        - Stop test"
echo "boot-start       - Start test"
echo "boot-reset       - Reset counter"
echo "boot-config      - Show configuration"
echo "systemctl status boot-test  - Service status"
echo ""
echo "=== Configuration ==="
echo "Edit: /etc/boot-test.conf"
echo "  MAX_REBOOTS=$MAX_REBOOTS"
echo "  REBOOT_DELAY=$REBOOT_DELAY"
echo ""
echo "=== Current Status ==="
/usr/local/bin/boot-status
