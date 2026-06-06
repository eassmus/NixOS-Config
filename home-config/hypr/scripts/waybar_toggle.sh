#!/usr/bin/bash
A=`ps -aux | grep -G '.:.. quickshell$'`
echo $A
if [[ $A == '' ]]; then
	quickshell &
else
	pkill quickshell
fi
