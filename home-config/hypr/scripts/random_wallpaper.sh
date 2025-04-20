pkill hyprpaper

WP_PATH="/home/pulsar/Wallpapers/Active/"
cd $WP_PATH
LAST=$(cat /home/pulsar/.config/hypr/scripts/last_wallpaper)

CHOSEN=$(ls | shuf -n 1)
while [ "$CHOSEN" = "$LAST" ]
do 
    CHOSEN=$(ls | shuf -n 1)
done

echo $WP_PATH$CHOSEN > "/home/pulsar/.config/hypr/scripts/last_wallpaper"

/home/pulsar/.config/hypr/scripts/change_wallpaper.sh $WP_PATH$CHOSEN
