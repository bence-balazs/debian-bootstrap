#!/bin/bash

SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

FILEPATH="$SAVE_DIR/screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

gnome-screenshot -acf "$FILEPATH"
