install_robotics() {
  local ros_apt_source_version ros_apt_source_deb ros_distro

  run sudo apt-get install -y software-properties-common
  run sudo add-apt-repository -y universe
  ros_apt_source_version=$(
    curl --retry 3 --retry-all-errors -fsSL \
      https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest |
      awk -F'"' '/tag_name/ { print $4; exit }'
  )
  if [[ -z $ros_apt_source_version ]]; then
    echo "failed to determine ros-apt-source release version" >&2
    return 1
  fi
  ros_apt_source_deb="/tmp/ros2-apt-source_${ros_apt_source_version}.${VERSION_CODENAME}_all.deb"
  run curl -fsSL -o "$ros_apt_source_deb" \
    "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ros_apt_source_version}/ros2-apt-source_${ros_apt_source_version}.${VERSION_CODENAME}_all.deb"
  run sudo dpkg -i "$ros_apt_source_deb"
  run sudo apt-get update
  install_apt_file "$root/packages/ubuntu/robotics.txt"

  ros_distro=${DOTFILES_ROS_DISTRO:-}
  if [[ -z $ros_distro ]]; then
    [[ $VERSION_ID == 22.04 ]] && ros_distro=humble || ros_distro=jazzy
  fi
  run sudo apt-get install -y \
    "ros-$ros_distro-desktop" \
    "ros-$ros_distro-rmw-cyclonedds-cpp" \
    ros-dev-tools
  [[ -e /etc/ros/rosdep/sources.list.d/20-default.list ]] || run sudo rosdep init
  run rosdep update
}
