#!/bin/sh

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'

removeAppLauncher() {
    rm -rf $HOME/.icon/nightlight
    rm $HOME/.local/bin/nightlight-linux
    rm $HOME/.local/share/applications/nightlight.desktop

    printf "%b\n" "${YELLOW}Done!${RC}"
    printf "%b\n" "${YELLOW}you might need to restart your device for Nightlight to be remove from your App Launcher${RC}"
    printf "%b\n" "${YELLOW}Enjoy :)${RC}"
}

run_script(){
    removeAppLauncher
}

run_script
