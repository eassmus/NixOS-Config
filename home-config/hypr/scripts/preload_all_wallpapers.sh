WP_PATH="/home/pulsar/Wallpapers/Active"
cd $WP_PATH

hyprpaper_config_file="$HOME/.config/hypr/hyprpaper.conf"
for FILE in $WP_PATH/*; do
  hyprctl hyprpaper preload $FILE
done
