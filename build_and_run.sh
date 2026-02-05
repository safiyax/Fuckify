#!/bin/bash

# Build and Run Script for Fuckify with Live Activity Widget
# This script builds the widget extension, main app, and deploys to physical device

set -e  # Exit on any error

# Handle Ctrl+C gracefully
trap 'echo -e "\n${RED}✗ Build cancelled by user${NC}"; exit 130' INT TERM

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="Fuckify"
SCHEME_WIDGET="EncounterActivityWidgetExtension"
SCHEME_APP="Fuckify"
CONFIGURATION="Debug"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Fuckify Build & Deploy Script${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Get list of available devices using xctrace (returns actual UDIDs for xcodebuild)
print_status "Finding available devices..."
devices_output=$(xcrun xctrace list devices 2>/dev/null)

if [ -z "$devices_output" ]; then
    print_error "No devices found!"
    print_warning "Make sure your device is connected and unlocked."
    exit 1
fi

# Parse devices into arrays
declare -a device_ids
declare -a device_names
index=0

# Extract only physical devices (not simulators or Mac)
# Format: "Device Name (iOS Version) (UDID)"
# We want lines under "== Devices ==" but not "== Devices Offline ==" or "== Simulators =="
in_devices_section=false

while IFS= read -r line; do
    # Check for section headers
    if [[ "$line" == "== Devices =="* ]]; then
        in_devices_section=true
        continue
    elif [[ "$line" == "== Devices Offline =="* ]] || [[ "$line" == "== Simulators =="* ]]; then
        in_devices_section=false
        continue
    fi
    
    # Skip empty lines or non-device lines
    if [[ ! "$in_devices_section" == true ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
        continue
    fi
    
    # Parse device line: "Name (iOS Version) (UDID)"
    # Extract UDID from last parentheses (simple and reliable)
    device_id=$(echo "$line" | grep -oE '\([0-9A-Z-]+\)' | tail -1 | tr -d '()')
    
    # Extract device name (everything before the first opening paren)
    device_name=$(echo "$line" | sed -E 's/ *\(.*//')
    
    # Only include physical devices (UDIDs starting with 00008...)
    # Exclude Mac (which has different format)
    if [[ -n "$device_id" ]] && [[ "$device_id" == 00008* ]]; then
        device_ids[$index]="$device_id"
        device_names[$index]="$device_name"
        ((index++))
    fi
done <<< "$devices_output"

# Check if we found any devices
if [ ${#device_ids[@]} -eq 0 ]; then
    print_error "No physical iOS devices found!"
    print_warning "Make sure your device is connected and unlocked."
    echo ""
    echo "Available devices:"
    echo "$devices_output" | grep -A 20 "== Devices =="
    exit 1
fi

# If only one device, use it automatically
if [ ${#device_ids[@]} -eq 1 ]; then
    DEVICE_ID="${device_ids[0]}"
    DEVICE_NAME="${device_names[0]}"
    print_success "Found 1 device: ${DEVICE_NAME}"
else
    # Multiple devices - let user choose
    echo ""
    echo -e "${YELLOW}Multiple devices found:${NC}"
    echo ""
    for i in "${!device_ids[@]}"; do
        echo "  $((i+1)). ${device_names[$i]}"
        echo "     ${BLUE}${device_ids[$i]}${NC}"
        echo ""
    done
    
    # Prompt for selection
    while true; do
        echo -n "Select device [1-${#device_ids[@]}]: "
        read -r selection
        
        # Validate input
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#device_ids[@]} ]; then
            DEVICE_ID="${device_ids[$((selection-1))]}"
            DEVICE_NAME="${device_names[$((selection-1))]}"
            print_success "Selected: ${DEVICE_NAME}"
            break
        else
            print_error "Invalid selection. Please enter a number between 1 and ${#device_ids[@]}"
        fi
    done
fi

echo ""

# Build Widget Extension
print_status "Building Widget Extension (${SCHEME_WIDGET})..."
xcodebuild build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_WIDGET}" \
    -configuration "${CONFIGURATION}" \
    -destination "id=${DEVICE_ID}" \
    | xcpretty

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    print_success "Widget Extension built successfully"
else
    print_error "Widget Extension build failed"
    exit 1
fi

# Build and Install Main App
print_status "Building Main App (${SCHEME_APP})..."
xcodebuild build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_APP}" \
    -configuration "${CONFIGURATION}" \
    -destination "id=${DEVICE_ID}" \
    | xcpretty

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    print_success "Main App built successfully"
else
    print_error "Main App build failed"
    exit 1
fi

# Find the built app bundle
print_status "Locating built app bundle..."
BUILD_DIR=$(xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_APP}" -configuration "${CONFIGURATION}" -showBuildSettings 2>/dev/null | grep " BUILD_DIR = " | awk '{print $3}')
APP_PATH="${BUILD_DIR}/${CONFIGURATION}-iphoneos/${PROJECT_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    print_error "Could not find built app at: $APP_PATH"
    print_warning "App may still be on device from previous build. Try launching manually."
else
    print_success "Found app bundle at: ${APP_PATH}"
    
    # Install using devicectl
    print_status "Installing on device..."
    install_output=$(xcrun devicectl device install app --device "${DEVICE_ID}" "${APP_PATH}" 2>&1)
    
    if [ $? -eq 0 ]; then
        print_success "App installed successfully"
    else
        # Check if error is because app is already installed
        if echo "$install_output" | grep -q "already installed"; then
            print_success "App already installed (updating)"
        else
            print_warning "Installation may have failed, but app might be usable"
            echo "$install_output" | head -3
        fi
    fi
fi

# Launch the app
print_status "Launching app on device..."
launch_output=$(xcrun devicectl device process launch --device "${DEVICE_ID}" "baby.safi.Fuckify" 2>&1)

if [ $? -eq 0 ]; then
    print_success "App launched successfully"
else
    print_warning "Auto-launch failed - please launch app manually on device"
    echo "$launch_output" | grep -i error | head -2
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Build and Deploy Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The app should now be running on your device."
echo "Test the Live Activity by:"
echo "  1. Tap '+' button in Calendar view"
echo "  2. Select 'Start Live Tracking'"
echo "  3. Choose partners"
echo "  4. Watch the Dynamic Island! 🎉"
echo ""
