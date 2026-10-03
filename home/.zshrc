# ============================================================================
# 1. CORE SETTINGS & OH-MY-ZSH
# ============================================================================
export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.local/bin:$PATH"
export _JAVA_AWT_WM_NONREPARENTING=1
ZSH_THEME="bira"

plugins=(
  git
  archlinux
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"
source <(fzf --zsh)   # FZF key bindings

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

# Highlight
ZSH_HIGHLIGHT_STYLES[comment]='fg=yellow,bold'


# ============================================================================
# 2. PATHS & ENVIRONMENT VARIABLES
# ============================================================================
# Custom Scripts
export MY_SCRIPTS="$HOME/myskrip"
export PATH="$PATH:$MY_SCRIPTS"

# Android SDK
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"

# Flutter
export PATH="$PATH:$HOME/flutter/bin"

# D-Bus & XDG
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Storage Paths
export hdd="/mnt/DATA_HDD"
export ssd1="/mnt/windows/acer"
export ssd2="/mnt/New_Volume"
export ssd3="/mnt/new_windows"

# games
export GAMES_DIR="/mnt/new_windows/games"
alias games='cd "$GAMES_DIR"'

# ============================================================================
# 3. ALIASES: NAVIGATION & STORAGE
# ============================================================================
alias hdd='cd $hdd'
alias ssd1='cd $ssd1'
alias ssd2='cd $ssd2'
alias ssd3='cd $ssd3'

# ============================================================================
# 4. ALIASES: SYSTEM & TOOLS
# ============================================================================
# File Listing (LSD)
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'

# Arch Maintenance
alias update='sudo pacman -Syu'
alias instal='sudo pacman -S'
alias mirrorsync='sudo reflector --latest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist'
alias hapus='~/myskrip/bersih.sh'

# Search & File
alias cari="$MY_SCRIPTS/carii.sh"
alias pmove='rsync -ah --progress --remove-source-files'
alias pcopy='rsync -ah --progress'

# semua skrip
alias skrip='~/myskrip/atur.sh'

# ============================================================================
# 5. ALIASES: HARDWARE & MONITORING
# ============================================================================
# CPU (atur_cpu.sh sudah tidak ada, fungsinya diambil alih atur_power.sh + cekcpu.sh)
alias powersave="$MY_SCRIPTS/atur_power.sh 1"
alias performance="$MY_SCRIPTS/atur_power.sh 3"
alias cekcpu="$MY_SCRIPTS/cekcpu.sh"

# GPU (Envycontrol)
alias gpuintel='sudo envycontrol -s integrated'
alias gpu2='sudo envycontrol -s hybrid'
alias gpunvidia='sudo envycontrol -s nvidia'

# System Health
alias ceksis="$MY_SCRIPTS/syscheck.sh"
alias hyprdiag="$MY_SCRIPTS/hyprfix.sh"
alias ceklog="$MY_SCRIPTS/ceklog.sh"


alias monitor="mo ~/.config/hypr/monitors.conf"

# ============================================================================
# 6. ALIASES: APPS, GAMES, WORK
# ============================================================================

# Virtualization, Gaming & Scripts
alias gamemode="$HOME/.config/hypr/scripts/GameMode.sh"
alias link='cd /mnt/New_Volume/followers/link && python link.py'

# Storage & Backup (mount-windows.sh/umount-windows.sh sudah tidak ada,
# digantikan mount.sh yang menu interaktifnya sudah mencakup mount & unmount)
alias mwin="$MY_SCRIPTS/mount.sh"
alias umwin="$MY_SCRIPTS/mount.sh"
alias backup="$MY_SCRIPTS/backup.sh"

# Notes
alias catat='mousepad ~/catat.txt'
alias perintah='mousepad ~/data/daftar_perintah.txt'
alias foll='mousepad ~/catatan1/follower.txt'

# ============================================================================
# 7. CUSTOM FUNCTIONS
# ============================================================================
# Extract file
extract () {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz)  tar xzf "$1" ;;
      *.bz2)     bunzip2 "$1" ;;
      *.rar)     unrar x "$1" ;;
      *.gz)      gunzip "$1" ;;
      *.tar)     tar xf "$1" ;;
      *.tbz2)    tar xjf "$1" ;;
      *.tgz)     tar xzf "$1" ;;
      *.zip)     unzip "$1" ;;
      *.Z)       uncompress "$1" ;;
      *.7z)      7z x "$1" ;;
      *) echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Keep one file
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
    rm -v ^"$1"
  fi
}

# Cek GPU
cekgpu () {
  echo "--- STATUS NVIDIA (RTX 3050) ---"
  nvidia-smi --query-gpu=utilization.gpu,power.draw,temperature.gpu \
    --format=csv,noheader,nounits | \
    awk -F', ' '{print "Usage: "$1"%\nPower: "$2"W\nTemp : "$3"°C"}'

  echo ""
  echo "--- STATUS INTEL (ALDER LAKE-P) ---"
  sudo intel_gpu_top -o - -s 500 -n 2 | grep "Render/3D" | tail -n 1 \
    || echo "Gagal membaca data Intel. Coba jalankan: sudo intel_gpu_top"
}


# ============================================================================
# 8. STARTUP & QUICK COMMANDS
# ============================================================================
fastfetch

# Scrcpy
alias hp='scrcpy -d -S --always-on-top --video-codec=h264 --video-bit-rate 12M --max-fps=60 --video-buffer=5'
alias hpwifi='scrcpy -e --max-size 1024 --video-bit-rate 2M --max-fps 30'


# System
alias xampp='sudo /opt/lampp/lampp'
alias mati='sudo shutdown now'

# config
alias pengaturan='~/myskrip/semua_config.sh'

# Cleanup (override sebelumnya)
alias hapuscache='sudo pacman -Sc'
alias jadwal='~/myskrip/cekjadwal.sh'

alias mo="mousepad"
alias zs="nano ~/.zshrc"

# ============================================================================
# 9. FAN CONTROL (NBFC)
# ============================================================================
alias fansenyap='nbfc set -s 20'
alias fansedang='nbfc set -s 50'
alias fanngebut='nbfc set -s 100'
alias fanauto='nbfc set --auto'
alias fancek='nbfc status'
alias fanset='nbfc set -s'
alias setpower='~/myskrip/atur_power.sh'


alias film='firefox ~/Projects/web/mediaplayer.html'
alias wa="wasistlos >/dev/null 2>&1 & whatsie"


export LS_COLORS=$LS_COLORS:"ow=01;34m:"

alias emulator='~/Android/Sdk/emulator/emulator -avd Small_Phone'


# Added by Antigravity CLI installer
export PATH="/home/adam/.local/bin:$PATH"

. "$HOME/.local/share/../bin/env"
