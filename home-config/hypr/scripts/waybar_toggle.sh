#!/usr/bin/bash 
A=`ps -aux | grep -G '.:.. waybar$'`
echo $A
if [[ $A == '' ]]; then
	waybar
else
	pkill waybar
fi
