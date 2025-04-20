pkill hyprpaper

WP_PATH="/home/pulsar/Wallpapers/Active/"
cd $WP_PATH
LAST=$(cat /home/pulsar/.config/hypr/scripts/last_wallpaper)

/home/pulsar/.config/hypr/scripts/change_wallpaper.sh $LAST
