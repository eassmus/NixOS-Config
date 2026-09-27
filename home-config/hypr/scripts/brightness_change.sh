declare -i change="$1"

# current brightness in percent (4th field of machine output, e.g. "95%")
CURR=$(brightnessctl -c backlight -m | cut -d, -f4 | tr -d '%')

# finer steps at low brightness
if [[ $CURR -lt 20 ]]; then
  change=$((change / 2))
fi

if [[ $change -lt 0 ]]; then
  brightnessctl -c backlight set "$((-change))%-"
else
  brightnessctl -c backlight set "${change}%+"
fi
