DISTRO="jazzy"

if [ $DISTRO = "humble" ]; then
source /opt/ros/humble/setup.zsh
source /usr/share/colcon_cd/function/colcon_cd.sh
elif [ $DISTRO = "jazzy" ]; then
source /opt/ros/jazzy/setup.zsh
source /usr/share/colcon_cd/function/colcon_cd.sh
fi

eval "$(register-python-argcomplete ros2)"
eval "$(register-python-argcomplete colcon)"
export RCUTILS_COLORIZED_OUTPUT=1
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export CYCLONEDDS_URI="file://$HOME/.config/cyclonedds.xml"