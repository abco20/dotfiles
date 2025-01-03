DISTRO="humble"

if [ $DISTRO = "humble" ]; then
source /opt/ros/humble/setup.zsh
source /usr/share/colcon_cd/function/colcon_cd.sh
fi

eval "$(register-python-argcomplete3 ros2)"
eval "$(register-python-argcomplete3 colcon)"
export RCUTILS_COLORIZED_OUTPUT=1