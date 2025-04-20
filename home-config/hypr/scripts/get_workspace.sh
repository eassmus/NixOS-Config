#!/bin/bash

A=$(hyprctl activeworkspace -j | grep '^    "name": "' | cut -c14)
echo $A
