pkill hyprpaper

WP_PATH="/home/pulsar/Wallpapers/Active/"
cd $WP_PATH
LAST=$(cat /home/pulsar/.config/hypr/scripts/last_wallpaper)

NEW=$LAST

for FILE in $WP_PATH*; do
  if [ "$FILE" == "$LAST" ]; then
    break
  fi
  NEW=$FILE
done

echo $NEW > "/home/pulsar/.config/hypr/scripts/last_wallpaper"

/home/pulsar/.config/hypr/scripts/change_wallpaper.sh $NEW

