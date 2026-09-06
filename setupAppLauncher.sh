#!/bin/sh

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'

setupAppLauncher() {

    mkdir -p $HOME/.icon/nightlight
    curl -L -o $HOME/.icon/nightlight/License_Agreement.txt https://github.com/ChesterTsai/NLIS/raw/dev/.icon/nightlight/License_Agreement.txt
    curl -L -o $HOME/.icon/nightlight/NL.png https://github.com/ChesterTsai/NLIS/raw/dev/.icon/nightlight/NL.png

    mkdir -p $HOME/.local/bin
    mv $PWD/nightlight-linux $HOME/.local/bin

    mkdir -p $HOME/.local/share/applications
    curl -L -o $HOME/.local/share/applications/nightlight.desktop https://github.com/ChesterTsai/NLIS/raw/dev/.local/share/applications/nightlight.desktop
    echo "Icon=$HOME/.icon/nightlight/NL.png" >> $HOME/.local/share/applications/nightlight.desktop
    if distrobox ls | grep -q "f44-nightlight"; then
        echo "Exec=distrobox-enter -n f44-nightlight -- $HOME/.local/bin/nightlight-linux" >> $HOME/.local/share/applications/nightlight.desktop
    else
        echo "Exec=$HOME/.local/bin/nightlight-linux" >> $HOME/.local/share/applications/nightlight.desktop
    fi

    printf "%b\n" "${YELLOW}Done!${RC}"
    printf "%b\n" "${YELLOW}you might need to restart your device for Nightlight to show up in your App Launcher${RC}"
    printf "%b\n" "${YELLOW}Enjoy :)${RC}"

}

run_script(){
    setupAppLauncher
}

run_script
