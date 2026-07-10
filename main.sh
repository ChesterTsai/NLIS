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

command_exists() {
    for cmd in "$@"; do
        export PATH="$HOME/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:$PATH"
        command -v "$cmd" >/dev/null 2>&1 || return 1
    done
    return 0
}

isAlpine() {

    . /etc/os-release</dev/tty
    if [ $ID = "alpine" ]; then
        return 1
    else
        return 0
    fi

}

alpineSetup() {

    str=$(tail -n 1 /etc/apk/repositories)
    if [[ $str == "#"* ]] && [[ $str == *"/community" ]]; then
        new_str=${str:1}
        echo $new_str | doas tee -a /etc/apk/repositories
        doas apk update
    fi

    doas apk add distrobox crun
    doas modprobe tun
    if ! grep -q tun /etc/modules; then
        echo tun | doas tee -a /etc/modules
    fi
    echo ${USER}:100000:65536 | doas tee -i /etc/subuid
    echo ${USER}:100000:65536 | doas tee -i /etc/subgid

    distrobox-create --name f44 --image fedora:44
    distrobox enter f44 -- sudo dnf install -y wget2-wget webkit2gtk4.1

    if [ -e nightlight-linux ]; then
        printf "%b\n" "${RED}ERROR!${RC}"
        printf "%b\n" "${RED}There's a file/directory named [nightlight-linux] in ${PWD},${RC}"
        printf "%b\n" "${RED}Please rename it or remove it and run the script again${RC}"
        printf "%b\n" "${RED}as it will conflict with the downloaded file.${RC}"
        return 0
    fi

    distrobox enter f44 -- wget http://update.nightlight.gg/desktop/latest/linux -O nightlight-linux
    distrobox enter f44 -- chmod +x nightlight-linux

    printf "\n\n\n\n\n"
    printf "%b\n" "${YELLOW}Download Completed!${RC}"
    printf "%b\n" "${YELLOW}currently nightlight-linux in the ${PWD} directory doesn't do anything by itself.${RC}"
    printf "%B\n" "${YELLOW}so making Nightlight show up on App Launcher is recommended on this distro.${RC}"

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
        passwd ${USER}
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
    PACKAGEMANAGER="pacman apt-get dnf zypper rpm-ostree"
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
            "$ESCALATION_TOOL" "$PACKAGER" install -y wget2-wget webkit2gtk4.1
            ;;
        rpm-ostree)
            "$PACKAGER" install -y wget2-wget webkit2gtk4.1
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
    isAlpine
    res=$?
    if [ $res = "1" ]; then
        sh -c 'echo -e "[Desktop Entry]\nName=NightLight\nExec=distrobox-enter -n f44 -- $HOME/.local/bin/nightlight-linux\nTerminal=false\nTy    pe=Application" > ~/.local/share/applications/nightlight.desktop'
    else
        sh -c 'echo -e "[Desktop Entry]\nName=NightLight\nExec=$HOME/.local/bin/nightlight-linux\nTerminal=false\nType=Application" > ~/.local/share/applications/nightlight.desktop'
    fi

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
isAlpine
res=$?
if [ $res = "0" ]; then
    installNightlight
else
    alpineSetup
fi
userDecision
