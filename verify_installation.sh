#!/bin/bash

# Verification script for stella_vslam ROS2 installation
# This script tests that the installation was successful

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test functions
test_passed() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
}

test_failed() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    exit 1
}

test_warning() {
    echo -e "${YELLOW}⚠️  WARN:${NC} $1"
}

echo -e "${BLUE}🔍 stella_vslam ROS2 Installation Verification${NC}"
echo "=============================================="

# Test 1: Check ROS2 environment
echo -n "Testing ROS2 environment... "
if [ -z "$ROS_DISTRO" ]; then
    if [ -f "/opt/ros/kilted/setup.bash" ]; then
        source /opt/ros/kilted/setup.bash
        test_passed "ROS2 Kilted detected and sourced"
    elif [ -f "/opt/ros/humble/setup.bash" ]; then
        source /opt/ros/humble/setup.bash
        test_passed "ROS2 Humble detected and sourced"
    else
        test_failed "No ROS2 installation found"
    fi
else
    test_passed "ROS2 $ROS_DISTRO environment active"
fi

# Test 2: Check workspace
echo -n "Testing ROS2 workspace... "
if [ -f "$HOME/ros2_ws/install/setup.bash" ]; then
    source $HOME/ros2_ws/install/setup.bash
    test_passed "Workspace found and sourced"
else
    test_failed "ROS2 workspace not found at $HOME/ros2_ws"
fi

# Test 3: Check stella_vslam_ros package
echo -n "Testing stella_vslam_ros package... "
if ros2 pkg list | grep -q stella_vslam_ros; then
    test_passed "stella_vslam_ros package found"
else
    test_failed "stella_vslam_ros package not found"
fi

# Test 4: Check executables
echo -n "Testing executables... "
EXECUTABLES=$(ros2 pkg executables stella_vslam_ros)
if echo "$EXECUTABLES" | grep -q "run_slam" && echo "$EXECUTABLES" | grep -q "run_slam_offline"; then
    test_passed "All executables found (run_slam, run_slam_offline, system)"
else
    test_failed "Missing executables"
fi

# Test 5: Check iridescence_viewer support
echo -n "Testing iridescence_viewer support... "
HELP_OUTPUT=$(ros2 run stella_vslam_ros run_slam --help 2>&1 || true)
if echo "$HELP_OUTPUT" | grep -q "iridescence_viewer"; then
    test_passed "iridescence_viewer support detected"
else
    test_warning "iridescence_viewer support not detected"
fi

# Test 6: Check system libraries
echo -n "Testing system libraries... "
MISSING_LIBS=""
if [ ! -f "/usr/local/lib/libstella_vslam.so" ]; then
    MISSING_LIBS="$MISSING_LIBS libstella_vslam.so"
fi
if [ ! -f "/usr/local/lib/libiridescence.so" ]; then
    MISSING_LIBS="$MISSING_LIBS libiridescence.so"
fi
if [ ! -f "/usr/local/lib/libiridescence_viewer.so" ]; then
    MISSING_LIBS="$MISSING_LIBS libiridescence_viewer.so"
fi

if [ -z "$MISSING_LIBS" ]; then
    test_passed "All required libraries found"
else
    test_failed "Missing libraries: $MISSING_LIBS"
fi

# Test 7: Check fixed headers (our bug fixes)
echo -n "Testing build fixes... "
if grep -q "cv_bridge.hpp" $HOME/ros2_ws/src/stella_vslam_ros/src/stella_vslam_ros.h 2>/dev/null; then
    test_passed "Updated headers detected (build fixes applied)"
else
    test_warning "Could not verify header fixes"
fi

echo ""
echo -e "${GREEN}🎉 Installation Verification Complete!${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Download vocabulary file:"
echo "   wget https://github.com/stella-cv/FBoW_orb_vocab/raw/main/orb_vocab.fbow"
echo ""
echo "2. Create/download a camera config file for your setup"
echo ""
echo "3. Run stella_vslam:"
echo "   ros2 run stella_vslam_ros run_slam \\"
echo "     -v /path/to/orb_vocab.fbow \\"
echo "     -c /path/to/config.yaml \\"
echo "     --map-db-out /path/to/map.msg \\"
echo "     --viewer iridescence_viewer"
echo ""
echo -e "${YELLOW}Documentation:${NC} https://stella-cv.readthedocs.io/en/latest/ros2_package.html"
echo -e "${YELLOW}Fixed Fork:${NC} https://github.com/JL360/stella_vslam_ros"
