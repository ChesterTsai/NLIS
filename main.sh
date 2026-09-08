#!/bin/sh

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'

checkArch() {
    if [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; then
        printf "%b\n" "${RED}Sorry, this architecture isn't supported!${RC}"
        exit 1
    fi
}

userDecision() {

    feature="1"

    while [ "$feature" != "0" ]
    do
        echo "[0] Exit the Script"
        echo "[1] Install Nightlight on Linux"
        echo "[2] Make Nightlight show up in App Launcher"
        echo "[3] Remove Nightlight from App Launcher"
        read -p "Select a feature you want to run: [1] " feature</dev/tty
        case "$feature" in
            "0")
                ;;
            "2")
                (curl -fsSL https://github.com/ChesterTsai/NLIS/raw/dev/features/setupAppLauncher.sh | sh)</dev/tty
                ;;
            "3")
                (curl -fsSL https://github.com/ChesterTsai/NLIS/raw/dev/features/removeAppLauncher.sh | sh)</dev/tty
                ;;
            *)
                (curl -fsSL https://github.com/ChesterTsai/NLIS/raw/dev/features/installNightLight.sh | sh)</dev/tty
                ;;
        esac
    done
}

run_script(){
    checkArch
    userDecision
}

run_script
