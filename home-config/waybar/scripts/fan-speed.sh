#/bin/bash

VAR=$(cat)
A= echo "$VAR" | sed -r 's/[Q]+/󰾆/g' | sed -r 's/[B]+/󰾅/g' | sed -r 's/[P]+/󰓅/g'
echo -e $A

