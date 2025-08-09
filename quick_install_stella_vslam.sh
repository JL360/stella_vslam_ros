#!/bin/bash

# Quick install script for stella_vslam with IridescenceViewer
# Uses the fixed fork with ROS2 Kilted build issues resolved

set -e

echo "🚀 Quick installing stella_vslam with IridescenceViewer..."
echo "This uses the fixed fork: https://github.com/JL360/stella_vslam_ros"

# Detect ROS2
if [ -z "$ROS_DISTRO" ]; then
    if [ -f "/opt/ros/kilted/setup.bash" ]; then
        export ROS_DISTRO="kilted"
    elif [ -f "/opt/ros/humble/setup.bash" ]; then
        export ROS_DISTRO="humble"
    else
        echo "❌ No ROS2 found. Please install ROS2 first."
        exit 1
    fi
fi

source /opt/ros/$ROS_DISTRO/setup.bash

# Install system dependencies
sudo apt update
sudo apt install -y libglm-dev libglfw3-dev libpng-dev libjpeg-dev \
    libeigen3-dev libboost-filesystem-dev libboost-program-options-dev \
    python3-rosdep python3-colcon-common-extensions build-essential cmake git

# Initialize rosdep
if [ ! -f "/etc/ros/rosdep/sources.list.d/20-default.list" ]; then
    sudo rosdep init
fi
rosdep update

# Install Iridescence
mkdir -p ~/lib && cd ~/lib
git clone https://github.com/koide3/iridescence.git
cd iridescence && git checkout 085322e0c949f75b67d24d361784e85ad7f197ab
git submodule update --init --recursive
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
make -j$(($(nproc) / 2)) && sudo make install

# Install stella_vslam
cd ~/lib
git clone --recursive --depth 1 https://github.com/stella-cv/stella_vslam.git
cd stella_vslam && mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
make -j$(($(nproc) / 2)) && sudo make install

# Install iridescence_viewer
cd ~/lib
git clone --recursive https://github.com/stella-cv/iridescence_viewer.git
cd iridescence_viewer && mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
make -j$(($(nproc) / 2)) && sudo make install

# Setup ROS2 workspace with fixed fork
mkdir -p ~/ros2_ws/src && cd ~/ros2_ws/src
git clone --recursive -b fix/ros2-kilted-build-issues --depth 1 https://github.com/JL360/stella_vslam_ros.git

cd ~/ros2_ws
rosdep install -y -i --from-paths src --skip-keys=stella_vslam
colcon build --symlink-install --packages-select stella_vslam_ros

echo "✅ Installation complete!"
echo "Run: source ~/ros2_ws/install/setup.bash"
echo "Then: ros2 run stella_vslam_ros run_slam [options]"
