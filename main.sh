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

distroboxSetup() {

    if ! command_exists distrobox; then
        printf "%b\n" "${RED}ERROR!${RC}"
        printf "%b\n" "${RED}Distrobox didn't exist, ${RC}"
        printf "%b\n" "${RED}Please install it with your package manager${RC}"
        printf "%b\n" "${RED}and run the script again afterwards.${RC}"
        exit 1
    fi

    if ! distrobox ls | grep -q "f44"; then
        distrobox-create --name f44 --image fedora:44
    fi
    distrobox enter f44 -- sudo dnf install -y wget2-wget webkit2gtk4.1

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
        printf "${YELLOW}Set a password for ${USER}, you'll need it later${RC}\n"
        "$ESCALATION_TOOL" passwd ${USER}</dev/tty
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
            "$ESCALATION_TOOL" "$PACKAGER" -S wget webkit2gtk-4.1 --noconfirm
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
        apk)
            str=$(tail -n 1 /etc/apk/repositories)
            if [[ $str == "#"* ]] && [[ $str == *"/community" ]]; then
                new_str=${str:1}
                echo $new_str | "$ESCALATION_TOOL" tee -a /etc/apk/repositories
                "$ESCALATION_TOOL" "$PACKAGER" update
            fi

            "$ESCALATION_TOOL" "$PACKAGER" add distrobox crun --no-interactive
            "$ESCALATION_TOOL" modprobe tun

            if ! grep -q tun /etc/modules; then
                echo tun | "$ESCALATION_TOOL" tee -a /etc/modules
            fi
            echo ${USER}:100000:65536 | "$ESCALATION_TOOL" tee -i /etc/subuid
            echo ${USER}:100000:65536 | "$ESCALATION_TOOL" tee -i /etc/subgid

            distrobox

            ;;
        *)
            printf "%b\n" "${RED}Unsupported package manager${RC}"
            printf "%b\n" "${RED}Trying to install nightlight with Distrobox...${RC}"
            distroboxSetup
            ;;
    esac
}

installNightlight() {

    if [ -e nightlight-linux ]; then
        printf "%b\n" "${RED}ERROR!${RC}"
        printf "%b\n" "${RED}There's a file/directory named [nightlight-linux] in ${PWD},${RC}"
        printf "%b\n" "${RED}Please rename it or remove it and run the script again${RC}"
        printf "%b\n" "${RED}as it will conflict with the downloaded file.${RC}"
        exit 1
    fi

    checkEscalationTool
    checkPassword
    checkSteamOS
    checkPackageManager
    installDependency

    if distrobox ls | grep -q "f44"; then
        distrobox enter f44 -- wget http://update.nightlight.gg/desktop/latest/linux -O nightlight-linux
        distrobox enter f44 -- chmod +x nightlight-linux
    else
        wget http://update.nightlight.gg/desktop/latest/linux -O nightlight-linux
        chmod +x nightlight-linux
    fi

    printf "\n\n\n\n\n"
    printf "%b\n" "${YELLOW}Download Completed!${RC}"

    if distrobox ls | grep -q "f44"; then
        printf "%b\n" "${YELLOW}currently nightlight-linux in the ${PWD} directory doesn't do anything by itself.${RC}"
        printf "%b\n" "${YELLOW}so making Nightlight show up on App Launcher is recommended on this distro.${RC}"
    else
        printf "%b\n" "${YELLOW}Double Click nightlight-linux in the ${PWD} directory in your file manager to open nightlight${RC}"
    fi

}

setupAppLauncher() {

    mkdir -p ~/.local/bin
    cp $PWD/nightlight-linux ~/.local/bin
    mkdir -p ~/.local/share/applications

    if distrobox ls | grep -q "f44"; then
        sh -c 'echo -e "[Desktop Entry]\nName=NightLight\nExec=distrobox-enter -n f44 -- $HOME/.local/bin/nightlight-linux\nTerminal=false\nType=Application" > ~/.local/share/applications/nightlight.desktop'
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
installNightlight
userDecision
