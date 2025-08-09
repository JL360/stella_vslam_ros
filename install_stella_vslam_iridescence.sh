#!/bin/bash

# stella_vslam ROS2 Installation Script with IridescenceViewer
# Uses the fixed fork at https://github.com/JL360/stella_vslam_ros
# This script installs only the IridescenceViewer variant

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    log_error "This script is designed for Ubuntu. Detected: $(lsb_release -d | cut -f2)"
    exit 1
fi

log_info "Starting stella_vslam ROS2 installation with IridescenceViewer..."
log_info "This script will install stella_vslam with the fixed build issues for ROS2 Kilted"

# Detect ROS2 distribution
if [ -z "$ROS_DISTRO" ]; then
    if [ -f "/opt/ros/kilted/setup.bash" ]; then
        export ROS_DISTRO="kilted"
    elif [ -f "/opt/ros/humble/setup.bash" ]; then
        export ROS_DISTRO="humble"
    else
        log_error "No ROS2 distribution detected. Please install ROS2 first."
        exit 1
    fi
fi

log_info "Detected ROS2 distribution: $ROS_DISTRO"

# Source ROS2
source /opt/ros/$ROS_DISTRO/setup.bash

# Update system packages
log_info "Updating system packages..."
sudo apt update

# Install ROS2 dependencies
log_info "Installing ROS2 dependencies..."
sudo apt install -y \
    python3-rosdep \
    python3-colcon-common-extensions \
    ros-$ROS_DISTRO-image-transport \
    ros-$ROS_DISTRO-cv-bridge \
    ros-$ROS_DISTRO-message-filters \
    ros-$ROS_DISTRO-tf2 \
    ros-$ROS_DISTRO-tf2-ros \
    ros-$ROS_DISTRO-tf2-geometry-msgs \
    ros-$ROS_DISTRO-rosbag2-cpp

# Install IridescenceViewer dependencies
log_info "Installing IridescenceViewer dependencies..."
sudo apt install -y \
    libglm-dev \
    libglfw3-dev \
    libpng-dev \
    libjpeg-dev \
    libeigen3-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev

# Install other required dependencies
log_info "Installing additional dependencies..."
sudo apt install -y \
    build-essential \
    cmake \
    git \
    wget \
    pkg-config \
    libyaml-cpp-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libatlas-base-dev \
    libsuitesparse-dev

# Initialize rosdep if not already done
if [ ! -f "/etc/ros/rosdep/sources.list.d/20-default.list" ]; then
    log_info "Initializing rosdep..."
    sudo rosdep init
fi
rosdep update

# Create lib directory
log_info "Creating library directory..."
mkdir -p ~/lib
cd ~/lib

# Install Iridescence (base library)
log_info "Installing Iridescence base library..."
if [ -d "iridescence" ]; then
    log_warning "Iridescence directory exists, removing..."
    rm -rf iridescence
fi

git clone https://github.com/koide3/iridescence.git
cd iridescence
git checkout 085322e0c949f75b67d24d361784e85ad7f197ab
git submodule update --init --recursive
mkdir -p build
cd build
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    ..
make -j$(($(nproc) / 2))
sudo make install
log_success "Iridescence base library installed"

# Install stella_vslam
log_info "Installing stella_vslam..."
cd ~/lib
if [ -d "stella_vslam" ]; then
    log_warning "stella_vslam directory exists, removing..."
    rm -rf stella_vslam
fi

git clone --recursive --depth 1 https://github.com/stella-cv/stella_vslam.git
cd stella_vslam

# Install dependencies via rosdep
rosdep install -y -i --from-paths . --skip-keys=opencv

mkdir -p build
cd build
source /opt/ros/$ROS_DISTRO/setup.bash
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
make -j$(($(nproc) / 2))
sudo make install
log_success "stella_vslam installed"

# Install iridescence_viewer
log_info "Installing iridescence_viewer..."
cd ~/lib
if [ -d "iridescence_viewer" ]; then
    log_warning "iridescence_viewer directory exists, removing..."
    rm -rf iridescence_viewer
fi

git clone --recursive https://github.com/stella-cv/iridescence_viewer.git
mkdir -p iridescence_viewer/build
cd iridescence_viewer/build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
make -j$(($(nproc) / 2))
sudo make install
log_success "iridescence_viewer installed"

# Create ROS2 workspace
log_info "Setting up ROS2 workspace..."
mkdir -p ~/ros2_ws/src
cd ~/ros2_ws/src

# Clone the fixed stella_vslam_ros fork
log_info "Cloning fixed stella_vslam_ros fork (with ROS2 Kilted build fixes)..."
if [ -d "stella_vslam_ros" ]; then
    log_warning "stella_vslam_ros directory exists, removing..."
    rm -rf stella_vslam_ros
fi

git clone --recursive -b fix/ros2-kilted-build-issues --depth 1 https://github.com/JL360/stella_vslam_ros.git
log_success "Fixed stella_vslam_ros fork cloned"

# Install ROS dependencies for the workspace
log_info "Installing ROS dependencies for workspace..."
cd ~/ros2_ws
rosdep install -y -i --from-paths src --skip-keys=stella_vslam

# Build the workspace
log_info "Building ROS2 workspace..."
source /opt/ros/$ROS_DISTRO/setup.bash
colcon build --symlink-install --packages-select stella_vslam_ros

if [ $? -eq 0 ]; then
    log_success "stella_vslam_ros built successfully!"
else
    log_error "Build failed. Please check the output above for errors."
    exit 1
fi

# Create setup script
log_info "Creating setup script..."
cat > ~/ros2_ws/setup_stella_vslam.sh << 'EOF'
#!/bin/bash
# Setup script for stella_vslam ROS2 workspace

# Source ROS2
source /opt/ros/$ROS_DISTRO/setup.bash

# Source workspace
source ~/ros2_ws/install/setup.bash

echo "stella_vslam ROS2 environment ready!"
echo ""
echo "Example usage:"
echo "  # For visual SLAM:"
echo "  ros2 run stella_vslam_ros run_slam \\"
echo "    -v /path/to/orb_vocab.fbow \\"
echo "    -c /path/to/config.yaml \\"
echo "    --map-db-out /path/to/map.msg \\"
echo "    --ros-args -p publish_tf:=false"
echo ""
echo "  # For localization:"
echo "  ros2 run stella_vslam_ros run_slam \\"
echo "    --disable-mapping \\"
echo "    -v /path/to/orb_vocab.fbow \\"
echo "    -c /path/to/config.yaml \\"
echo "    --map-db-in /path/to/map.msg \\"
echo "    --ros-args -p publish_tf:=false"
EOF

chmod +x ~/ros2_ws/setup_stella_vslam.sh

# Final success message
log_success "Installation completed successfully!"
echo ""
log_info "To use stella_vslam:"
log_info "1. Source the setup script: source ~/ros2_ws/setup_stella_vslam.sh"
log_info "2. Download vocabulary file: wget https://github.com/stella-cv/FBoW_orb_vocab/raw/main/orb_vocab.fbow"
log_info "3. Create a config file for your camera setup"
log_info "4. Run stella_vslam with the commands shown in the setup script"
echo ""
log_info "Documentation: https://stella-cv.readthedocs.io/en/latest/ros2_package.html"
log_info "Fixed fork repository: https://github.com/JL360/stella_vslam_ros"
echo ""
log_success "Happy SLAM-ing! 🚀"
