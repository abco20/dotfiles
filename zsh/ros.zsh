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
