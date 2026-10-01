#!/usr/bin/bash
# debug logging off: quickshell otherwise writes ~9 KB/s of internal debug lines to its log
if pgrep quickshell >/dev/null; then
	pkill quickshell
else
	quickshell --log-rules '*.debug=false' &
fi
