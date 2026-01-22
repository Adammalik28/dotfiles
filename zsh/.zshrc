# -------------------------------------------------------------------------
# 1. CORE SETTINGS & OH-MY-ZSH
# -------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="bira"

plugins=(
    git 
    archlinux 
    zsh-autosuggestions 
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh
source <(fzf --zsh) # FZF Key bindings

# History Settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
ZSH_HIGHLIGHT_STYLES[comment]='fg=yellow,bold'

# -------------------------------------------------------------------------
# 2. PATHS & ENVIRONMENT VARIABLES
# -------------------------------------------------------------------------
# My Scripts Folder
export MY_SCRIPTS="$HOME/myskrip"
export PATH="$PATH:$MY_SCRIPTS"
export kali="/mnt/kali/home/adam"

# Android SDK
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools

# D-Bus & XDG
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Definisi Variabel (Alamat/Path) - WAJIB pakai export agar dikenali sistem
export hdd="/mnt/DATA_HDD"
export ssd2="/mnt/DRIVE_D"
export ssd1="/mnt/windows/acer"

# Definisi Alias (Perintah/Shortcut)
alias hdd="cd $hdd"
alias ssd2="cd $ssd2"
alias ssd1="cd $ssd1"

# -------------------------------------------------------------------------
# 3. ALIASES: SYSTEM & TOOLS
# -------------------------------------------------------------------------
# File Listing (LSD)
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'

# Arch Maintenance
alias update='sudo pacman -Syu'
alias mirrorsync='sudo reflector --latest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist'
alias hapus='~/myskrip/bersih.sh'

# Search & File Management
alias cari="$MY_SCRIPTS/carii.sh"
alias pmove='rsync -ah --progress --remove-source-files'
alias pcopy='rsync -ah --progress'

# -------------------------------------------------------------------------
# 4. ALIASES: HARDWARE & MONITORING
# -------------------------------------------------------------------------
# CPU Management
alias powersave="$MY_SCRIPTS/atur_cpu.sh 2"
alias peformance="$MY_SCRIPTS/atur_cpu.sh 1"
alias cekcpu="$MY_SCRIPTS/atur_cpu.sh 3"

# GPU Management (Envycontrol)
alias gpuintel='sudo envycontrol -s integrated'
alias gpu2='sudo envycontrol -s hybrid'
alias gpunvidia='sudo envycontrol -s nvidia'
alias cekgpu='sudo envycontrol -q'

# System Health
alias ceksis="$MY_SCRIPTS/syscheck.sh"
alias ceklog="$MY_SCRIPTS/hyprfix.sh"

# -------------------------------------------------------------------------
# 5. ALIASES: APPS, GAMES, & WORK
# -------------------------------------------------------------------------
# WhatsApp Dual Account (Perbaikan menggunakan Fungsi)
# WhatsApp Dual Account
alias wa1="$MY_SCRIPTS/whatsapp-dual.sh 1"
alias wa2="$MY_SCRIPTS/whatsapp-dual.sh 2"
# Gunakan path lengkap di sini agar nohup tidak bingung
alias wa='nohup /home/adam/myskrip/whatsapp-dual.sh 1 >/dev/null 2>&1 & nohup /home/adam/myskrip/whatsapp-dual.sh 2 >/dev/null 2>&1 &'

# Virtualization & Gaming
alias kali_linux="$MY_SCRIPTS/start_kali.sh"
alias exit_kali="$MY_SCRIPTS/exit_kali.sh"
alias tekken="$MY_SCRIPTS/run-tekken7.sh"
alias gamemode="$MY_SCRIPTS/gamemode.sh"

# Storage & Backup
alias mwin="$MY_SCRIPTS/mount-windows.sh"
alias umwin="$MY_SCRIPTS/umount-windows.sh"
alias backup="$MY_SCRIPTS/backup.sh"

# Notes
alias catat='mousepad ~/data/catatan.txt'
alias perintah='mousepad ~/data/daftar_perintah.txt'

# -------------------------------------------------------------------------
# 6. CUSTOM FUNCTIONS
# -------------------------------------------------------------------------
# Extract any compressed file
extract () {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar x $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Keep one file, delete others in folder
simpan () {
    if [ -z "$1" ]; then
        echo "Contoh penggunaan: simpan catatan.txt"
        return 1
    fi
    echo "Peringatan: Semua file akan dihapus KECUALI '$1'"
    read -q "choice?Apakah anda yakin? (y/n) "
    echo
    if [[ "$choice" == "y" ]]; then
        setopt localoptions extendedglob
        rm -v ^$1
    fi
}

tarik() {
    FILE=$(ls /mnt/kali/home/adam/ | fzf)
    if [ -n "$FILE" ]; then
        cp -r "/mnt/kali/home/adam/$FILE" ~/Downloads/kali_drop/
        echo "Berhasil mengambil $FILE"
    fi
}

# -------------------------------------------------------------------------
# 7. STARTUP COMMANDS
# -------------------------------------------------------------------------
fastfetch
