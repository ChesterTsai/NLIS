#!/bin/bash

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'

checkArch() {
    if [ "$(uname -m)" != "x86_64" ] && [ "$(uname -m)" != "amd64" ]; then
        printf "%b\n" "${RED}Sorry, this architecture isn't supported!${RC}"
        exit 1
    fi
}

command_exists() {
    for cmd in "$@"; do
        export PATH="$HOME/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:$PATH"
        command -v "$cmd" >/dev/null 2>&1 || return 1
    done
    return 0
}

checkEscalationTool() {
    ## Check for escalation tools.
    if [ -z "$ESCALATION_TOOL_CHECKED" ]; then
        if [ "$(id -u)" = "0" ]; then
            ESCALATION_TOOL="eval"
            ESCALATION_TOOL_CHECKED=true
            return 0
        fi

        ESCALATION_TOOLS='sudo doas'
        for tool in ${ESCALATION_TOOLS}; do
            if command_exists "${tool}"; then
                ESCALATION_TOOL=${tool}
                ESCALATION_TOOL_CHECKED=true
                return 0
            fi
        done

        printf "%b\n" "${RED}Can't find a supported escalation tool${RC}"
        exit 1
    fi
}

checkPassword() {

    while [ "$(passwd -S ${USER} | awk '{print $2}')" = "NP" ]
    do
        printf "%b" "${YELLOW}Set a password for ${USER}, you'll need it later${RC}\n"
        "$ESCALATION_TOOL" passwd ${USER}
    done

}

checkSteamOS() {
    if ! command_exists steamos-readonly; then
        return 0
    fi

    if [ "$($ESCALATION_TOOL steamos-readonly status)" = "enabled" ]; then
        printf "%b\n" "${YELLOW}Disabling readonly mode${RC}"
        "$ESCALATION_TOOL" steamos-readonly disable
    fi

    printf "%b\n" "${YELLOW}Setting up PGP keys${RC}"
    "$ESCALATION_TOOL" pacman-key --init
    "$ESCALATION_TOOL" pacman-key --populate archlinux
    "$ESCALATION_TOOL" pacman-key --populate holo

}

checkPackageManager() {
    ## Check Package Manager
    PACKAGEMANAGER="pacman apt-get dnf zypper rpm-ostree apk"
    for pgm in ${PACKAGEMANAGER}; do
        if command_exists "${pgm}"; then
            PACKAGER=${pgm}
            break
        fi
    done

    if [ -z "$PACKAGER" ]; then
        printf "%b\n" "${RED}Can't find a supported package manager${RC}"
        exit 1
    fi
}

installDependency() {

    printf "%b\n" "${YELLOW}Installing necessary dependency${RC}"

    case "$PACKAGER" in
        pacman)
            "$ESCALATION_TOOL" "$PACKAGER" -S wget webkit2gtk-4.1
            ;;
        dnf)
            "$ESCALATION_TOOL" "$PACKAGER" install wget2-wget webkit2gtk4.1
            ;;
        rpm-ostree)
            "$PACKAGER" install wget2-wget webkit2gtk4.1
            printf "%b\n" "${YELLOW}you might need to restart.${RC}"
            ;;
        apt-get|zypper)
            "$ESCALATION_TOOL" "$PACKAGER" install -y wget webkit2gtk-4.1
            ;;
        *)
            printf "%b\n" "${RED}Unsupported package manager${RC}"
            ;;
    esac
}

installNightlight() {

    checkEscalationTool
    checkPassword
    checkSteamOS
    checkPackageManager
    installDependency

    if [ -e nightlight-linux ]; then
        printf "%b\n" "${RED}ERROR!${RC}"
        printf "%b\n" "${RED}There's a file/directory named [nightlight-linux] in ${PWD},${RC}"
        printf "%b\n" "${RED}Please rename it or remove it and run the script again${RC}"
        printf "%b\n" "${RED}as it will conflict with the downloaded file.${RC}"
        return 0
    fi

    wget http://update.nightlight.gg/desktop/latest/linux -O nightlight-linux
    chmod +x nightlight-linux

    printf "\n\n\n\n\n"
    printf "%b\n" "${YELLOW}Download Completed!${RC}"
    printf "%b\n" "${YELLOW}Double Click nightlight-linux in the ${PWD} directory in your file manager to open nightlight${RC}"
}

setupAppLauncher() {

    mkdir -p ~/.local/bin
    cp $PWD/nightlight-linux ~/.local/bin
    mkdir -p ~/.local/share/applications
    sh -c 'echo -e "[Desktop Entry]\nName=NightLight\nExec=$HOME/.local/bin/nightlight-linux\nTerminal=false\nType=Application" > ~/.local/share/applications/nightlight.desktop'

}

userDecision() {

    read -p "Do you want Nightlight to show up in your app launcher? (y/n) [n] " appla</dev/tty
    if [ "$appla" = "y" ] || [ "$appla" = "Y" ]; then
        setupAppLauncher
        printf "%b\n" "${YELLOW}Done!${RC}"
        printf "%b\n" "${YELLOW}you might need to restart for Nightlight to show up in your App Launcher${RC}"
        printf "%b\n" "${YELLOW}Enjoy :)${RC}"
    else
        return 0
    fi
}

checkArch
installNightlight
userDecision
