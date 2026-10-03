#!/bin/bash

# --- Warna ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}=================================================="
echo -e "       HYPRLAND ULTIMATE DIAGNOSTIC TOOL"
echo -e "==================================================${NC}"

# 1. KONFIGURASI HYPRLAND
echo -e "${YELLOW}[1/6] Mengecek Syntax Config...${NC}"
ERRORS=$(hyprctl configerrors)
if [[ "$ERRORS" == *"No errors found"* ]] || [ -z "$ERRORS" ]; then
    echo -e "${GREEN}✔ Config Bersih.${NC}"
else
    echo -e "${RED}✘ Error di Config:${NC}\n$ERRORS"
fi

# 2. XDG DESKTOP PORTAL & SERVICE
echo -e "\n${YELLOW}[2/6] Mengecek Portals & User Services...${NC}"
SERVICES=("xdg-desktop-portal-hyprland" "xdg-desktop-portal" "waybar")
for SVC in "${SERVICES[@]}"; do
    if pgrep -f "$SVC" > /dev/null; then
        echo -e "${GREEN}✔ $SVC berjalan.${NC}"
    else
        echo -e "${RED}✘ $SVC MATI!${NC}"
    fi
done

# Cek Notification Daemon (SwayNC / Mako / Dunst)
if pgrep -x swaync > /dev/null; then
    echo -e "${GREEN}✔ Notifikasi: swaync berjalan.${NC}"
elif pgrep -x mako > /dev/null; then
    echo -e "${GREEN}✔ Notifikasi: mako berjalan.${NC}"
elif pgrep -x dunst > /dev/null; then
    echo -e "${GREEN}✔ Notifikasi: dunst berjalan.${NC}"
else
    echo -e "${RED}✘ Notification Daemon MATI! (swaync/mako/dunst)${NC}"
fi

# 3. ENVIRONMENT VARIABLES (Penting untuk NVIDIA)
echo -e "\n${YELLOW}[3/6] Mengecek Variabel Lingkungan NVIDIA...${NC}"
ENV_VARS=("LIBVA_DRIVER_NAME" "__GLX_VENDOR_LIBRARY_NAME" "XDG_SESSION_TYPE")
for VAR in "${ENV_VARS[@]}"; do
    if [ -z "${!VAR:-}" ]; then
        echo -e "${RED}✘ $VAR tidak diatur!${NC}"
    else
        echo -e "${GREEN}✔ $VAR = ${!VAR}${NC}"
    fi
done
# Catatan khusus GBM_BACKEND
if [ -n "${GBM_BACKEND:-}" ]; then
    echo -e "${YELLOW}ℹ GBM_BACKEND = $GBM_BACKEND (di Hyprland modern sering kali sebaiknya dikosongkan)${NC}"
fi

# 4. KESEHATAN DRIVER & KERNEL (NVIDIA/ZEN)
echo -e "\n${YELLOW}[4/6] Mengecek Driver & DRM...${NC}"
if lsmod | grep -q nvidia; then
    echo -e "${GREEN}✔ Modul NVIDIA ter-load.${NC}"
    MODESET=$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo "N/A")
    [ "$MODESET" = "Y" ] && echo -e "${GREEN}✔ DRM Modeset: Aktif.${NC}" || echo -e "${RED}✘ DRM Modeset: MATI ($MODESET).${NC}"
else
    echo -e "${RED}✘ Driver NVIDIA tidak terdeteksi!${NC}"
fi

# 5. DEPENDENCIES CHECK (Kebutuhan Dasar)
echo -e "\n${YELLOW}[5/6] Mengecek Aplikasi Pendukung...${NC}"
APPS=("qt5-wayland" "qt6-wayland" "polkit-kde-agent" "swww" "swaync")
for APP in "${APPS[@]}"; do
    if pacman -Qs "$APP" > /dev/null; then
        echo -e "${GREEN}✔ $APP terinstall.${NC}"
    else
        echo -e "${YELLOW}i $APP tidak ditemukan (Disarankan install).${NC}"
    fi
done

# 6. LOG ERROR TERBARU
echo -e "\n${YELLOW}[6/6] Baris Terakhir Log Hyprland...${NC}"
HYPR_LOG="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/hyprland.log"
if [ -f "$HYPR_LOG" ]; then
    tail -n 5 "$HYPR_LOG" | sed 's/^/  /'
elif journalctl --user -u hyprland -n 5 --no-pager &>/dev/null; then
    journalctl --user -u hyprland -n 5 --no-pager | sed 's/^/  /'
else
    echo -e "  Log tidak tersedia."
fi

echo -e "${BLUE}==================================================${NC}"
