#!/bin/bash
# Acer Nitro 5 - Ultimate Syscheck (Upgraded)

# Colors
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# Bar visual
make_bar() {
    local val=$1 max=$2 width=20
    local filled=$(awk "BEGIN {printf \"%d\", ($val/$max)*$width}" 2>/dev/null || echo 0)
    [ "$filled" -gt "$width" ] 2>/dev/null && filled=$width
    local empty=$((width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo "$bar"
}

# Color by level
color_by_level() {
    local val=${1%.*} warn=$2 crit=$3
    if [ "${val:-0}" -ge "${crit:-90}" ] 2>/dev/null; then echo -e "${RED}"
    elif [ "${val:-0}" -ge "${warn:-70}" ] 2>/dev/null; then echo -e "${YELLOW}"
    else echo -e "${GREEN}"; fi
}

# Sudo sekali di awal
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}Beberapa fitur butuh sudo. Masukkan password:${NC}"
        sudo -v 2>/dev/null || echo -e "${RED}Sudo gagal. Beberapa data mungkin tidak tampil.${NC}"
    fi
}

print_header() {
    local ts; ts=$(date '+%A, %d %B %Y  %H:%M:%S')
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║       ACER NITRO 5 — ULTIMATE SYSCHECK           ║"
    printf "║  %-48s║\n" "$ts"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

section_hardware() {
    echo -e "${BLUE}${BOLD}┌─ HARDWARE MODE ────────────────────────────────┐${NC}"
    local gov; gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
    local gpu_mode; gpu_mode=$(envycontrol -q 2>/dev/null || echo "integrated")
    local cpu_freq; cpu_freq=$(awk '{printf "%.0f MHz", $1/1000}' /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "N/A")
    local cpu_cores; cpu_cores=$(nproc)
    echo -e "  CPU Governor : ${YELLOW}${BOLD}$gov${NC}"
    echo -e "  CPU Freq     : ${YELLOW}$cpu_freq${NC}  (${cpu_cores} cores)"
    echo -e "  GPU Mode     : ${GREEN}${BOLD}$gpu_mode${NC}"
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"
}

section_thermal() {
    echo -e "${BLUE}${BOLD}┌─ THERMAL & FANS ───────────────────────────────┐${NC}"
    local cpu_temp_raw; cpu_temp_raw=$(sensors 2>/dev/null | grep "Package id 0" | awk '{print $4}' | tr -d '+°C')
    local cpu_temp="${cpu_temp_raw:-0}"
    local gpu_mode; gpu_mode=$(envycontrol -q 2>/dev/null || echo "integrated")
    local gpu_name gpu_temp_val

    if [[ "$gpu_mode" == *"nvidia"* ]] || [[ "$gpu_mode" == *"hybrid"* ]]; then
        gpu_name="NVIDIA RTX 3050"
        gpu_temp_val=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo "OFF")
    else
        gpu_name="Intel Iris Xe"; gpu_temp_val="${cpu_temp_raw:-N/A}"
    fi

    local max_fan=7200
    local fan1_rpm; fan1_rpm=$(sensors 2>/dev/null | grep "fan1" | awk '{print $2}')
    local fan2_rpm; fan2_rpm=$(sensors 2>/dev/null | grep "fan2" | awk '{print $2}')
    local fan1_display fan2_display

    if [ -n "$fan1_rpm" ] && [ "$fan1_rpm" -ne 0 ] 2>/dev/null; then
        local f1p; f1p=$(awk "BEGIN {printf \"%.1f\", ($fan1_rpm/$max_fan)*100}")
        local f1bar; f1bar=$(make_bar "$fan1_rpm" "$max_fan")
        fan1_display="${fan1_rpm} RPM (${f1p}%)  ${CYAN}${f1bar}${NC}"
    else
        fan1_display="0 RPM (0%)  ${DIM}░░░░░░░░░░░░░░░░░░░░${NC}"
    fi

    if [ -n "$fan2_rpm" ] && [ "$fan2_rpm" -ne 0 ] 2>/dev/null; then
        local f2p; f2p=$(awk "BEGIN {printf \"%.1f\", ($fan2_rpm/$max_fan)*100}")
        local f2bar; f2bar=$(make_bar "$fan2_rpm" "$max_fan")
        fan2_display="${fan2_rpm} RPM (${f2p}%)  ${CYAN}${f2bar}${NC}"
    else
        fan2_display="0 RPM (0%)  ${DIM}░░░░░░░░░░░░░░░░░░░░${NC}"
    fi

    local cpu_col; cpu_col=$(color_by_level "$cpu_temp" 70 90)
    local gpu_col; gpu_col=$(color_by_level "$gpu_temp_val" 70 90)
    local cpu_bar; cpu_bar=$(make_bar "$cpu_temp" 100)
    local gpu_bar; gpu_bar=$(make_bar "${gpu_temp_val:-0}" 100)

    echo -e "  CPU Temp     : ${cpu_col}${BOLD}${cpu_temp_raw:-N/A}°C${NC}  ${cpu_col}${cpu_bar}${NC}"
    echo -e "  GPU Temp     : ${gpu_col}${BOLD}${gpu_temp_val}°C${NC}  ${gpu_col}${gpu_bar}${NC}  ${DIM}(${gpu_name})${NC}"
    echo -e "  Fan 1 (CPU)  : $fan1_display"
    echo -e "  Fan 2 (GPU)  : $fan2_display"
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"
}

section_battery() {
    echo -e "${BLUE}${BOLD}┌─ BATTERY & POWER ──────────────────────────────┐${NC}"
    local batt_path; batt_path=$(upower -e 2>/dev/null | grep 'BAT')
    if [ -z "$batt_path" ]; then
        echo -e "  ${RED}Baterai tidak terdeteksi.${NC}"
        echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"; return
    fi
    local batt_info; batt_info=$(upower -i "$batt_path" 2>/dev/null)
    local batt_pct; batt_pct=$(echo "$batt_info" | grep "percentage" | awk '{print $2}' | tr -d '%')
    local batt_stat; batt_stat=$(echo "$batt_info" | grep " state" | awk '{print $2}')
    local batt_draw; batt_draw=$(echo "$batt_info" | grep "energy-rate" | awk '{print $2 " " $3}')
    local batt_health; batt_health=$(echo "$batt_info" | grep "capacity" | awk '{print $2}')
    local batt_time; batt_time=$(echo "$batt_info" | grep "time to" | awk '{$1=$2=""; print $0}' | xargs)

    local inv_pct=$(( 100 - ${batt_pct:-50} ))
    local batt_col; batt_col=$(color_by_level "$inv_pct" 40 70)
    local batt_bar; batt_bar=$(make_bar "${batt_pct:-0}" 100)

    echo -e "  Status       : ${YELLOW}${BOLD}${batt_stat^}${NC}"
    echo -e "  Persentase   : ${batt_col}${BOLD}${batt_pct}%${NC}  ${batt_col}${batt_bar}${NC}"
    [ -n "$batt_time" ] && echo -e "  Estimasi     : ${CYAN}$batt_time${NC}"
    echo -e "  Power Draw   : ${PURPLE}${batt_draw:-N/A}${NC}"
    echo -e "  Health/Cap   : ${CYAN}${batt_health:-N/A}${NC}"
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"
}

section_storage_thermal() {
    echo -e "${BLUE}${BOLD}┌─ STORAGE THERMAL ──────────────────────────────┐${NC}"
    local ssd_temp; ssd_temp=$(sudo smartctl -a /dev/nvme0n1 2>/dev/null | grep "Temperature:" | awk '{print $2 " " $3}' | head -n 1)
    local hdd_temp; hdd_temp=$(sudo smartctl -a /dev/sda -d ata 2>/dev/null | grep "Temperature_Celsius" | awk '{print $10}')
    local ssd_num; ssd_num=$(echo "$ssd_temp" | awk '{print $1}')
    local ssd_col; ssd_col=$(color_by_level "${ssd_num:-0}" 55 70)
    echo -e "  SSD NVMe     : ${ssd_col}${BOLD}${ssd_temp:-N/A}${NC}"
    if [ -n "$hdd_temp" ] && [ "$hdd_temp" != "N/A" ]; then
        local hdd_col; hdd_col=$(color_by_level "$hdd_temp" 45 55)
        echo -e "  HDD SATA     : ${hdd_col}${BOLD}${hdd_temp}°C${NC}"
    fi
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"
}

section_memory() {
    echo -e "${BLUE}${BOLD}┌─ MEMORY ───────────────────────────────────────┐${NC}"
    local ram_used; ram_used=$(free -m | awk '/Mem:/ {print $3}')
    local ram_total; ram_total=$(free -m | awk '/Mem:/ {print $2}')
    local ram_pct; ram_pct=$(awk "BEGIN {printf \"%d\", ($ram_used/$ram_total)*100}")
    local ram_bar; ram_bar=$(make_bar "$ram_used" "$ram_total")
    local ram_col; ram_col=$(color_by_level "$ram_pct" 70 90)
    local swap_used; swap_used=$(free -m | awk '/Swap:/ {print $3}')
    local swap_total; swap_total=$(free -m | awk '/Swap:/ {print $2}')

    printf "  ${BOLD}%-8s %-8s %-8s %s${NC}\n" "TYPE" "USED" "TOTAL" "USAGE"
    printf "  %-8s %-8s %-8s " "RAM" "$(free -h | awk '/Mem:/ {print $3}')" "$(free -h | awk '/Mem:/ {print $2}')"
    echo -e "${ram_col}${ram_bar} ${ram_pct}%${NC}"

    if [ "${swap_total:-0}" -gt 0 ] 2>/dev/null; then
        local swap_pct; swap_pct=$(awk "BEGIN {printf \"%d\", ($swap_used/$swap_total)*100}")
        local swap_bar; swap_bar=$(make_bar "$swap_used" "$swap_total")
        local swap_col; swap_col=$(color_by_level "$swap_pct" 50 80)
        printf "  %-8s %-8s %-8s " "SWAP" "$(free -h | awk '/Swap:/ {print $3}')" "$(free -h | awk '/Swap:/ {print $2}')"
        echo -e "${swap_col}${swap_bar} ${swap_pct}%${NC}"
    fi
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"
}

section_storage_usage() {
    echo -e "${BLUE}${BOLD}┌─ STORAGE USAGE ────────────────────────────────┐${NC}"
    printf "  ${BOLD}%-12s %-6s %-6s %-6s %-5s${NC}\n" "MOUNT" "SIZE" "USED" "AVAIL" "USE%"
    df -h | grep -E '^/dev/nvme|^/dev/sda|^/dev/sdb' | while read -r dev size used avail pct mount; do
        local pct_num=${pct//%/}
        local col; col=$(color_by_level "$pct_num" 75 90)
        printf "  %-12s %-6s %-6s %-6s ${col}%-5s${NC}\n" "$mount" "$size" "$used" "$avail" "$pct"
    done
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"
}

section_security() {
    echo -e "${PURPLE}${BOLD}┌─ SECURITY ─────────────────────────────────────┐${NC}"
    local ufw_status; ufw_status=$(sudo ufw status 2>/dev/null | head -n 1 | awk '{print $2}')
    local ufw_col
    [[ "${ufw_status,,}" == "active" ]] && ufw_col="${GREEN}" || ufw_col="${RED}"
    echo -e "  UFW Status   : ${ufw_col}${BOLD}${ufw_status^^:-UNKNOWN}${NC}"
    echo -e "\n  ${BOLD}${YELLOW}PORT       SERVICE${NC}"
    sudo ss -tulnpH 2>/dev/null | awk '{
        split($5,a,":"); p=a[length(a)];
        split($7,b,"\""); pr=b[2];
        if(pr=="") pr="-"; print p " " pr
    }' | sort -un | head -n 8 | while read -r p pr; do
        printf "  %-10s %-20s\n" "$p" "$pr"
    done
    echo -e "${PURPLE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"
}

section_gpu() {
    echo -e "${BLUE}${BOLD}┌─ GPU REAL-TIME LOAD ───────────────────────────┐${NC}"
    local nvd_info; nvd_info=$(nvidia-smi --query-gpu=utilization.gpu,power.draw,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null)
    if [ -n "$nvd_info" ]; then
        local nvd_load nvd_watt nvd_mem_used nvd_mem_total
        nvd_load=$(echo "$nvd_info" | awk -F', ' '{print $1}')
        nvd_watt=$(echo "$nvd_info" | awk -F', ' '{print $2}')
        nvd_mem_used=$(echo "$nvd_info" | awk -F', ' '{print $3}')
        nvd_mem_total=$(echo "$nvd_info" | awk -F', ' '{print $4}')
        local nvd_bar; nvd_bar=$(make_bar "$nvd_load" 100)
        local nvd_mem_bar; nvd_mem_bar=$(make_bar "$nvd_mem_used" "$nvd_mem_total")
        local nvd_col; nvd_col=$(color_by_level "$nvd_load" 60 85)
        echo -e "  NVIDIA Load  : ${nvd_col}${BOLD}${nvd_load}%${NC}  ${nvd_col}${nvd_bar}${NC}  ${PURPLE}${nvd_watt}W${NC}"
        echo -e "  NVIDIA VRAM  : ${CYAN}${nvd_mem_used}/${nvd_mem_total} MiB${NC}  ${CYAN}${nvd_mem_bar}${NC}"
    else
        echo -e "  NVIDIA       : ${RED}OFF / Not Detected${NC}"
    fi
    local intel_load; intel_load=$(sudo intel_gpu_top -o - -s 100 -n 1 2>/dev/null | grep "Render/3D" | tail -n 1 | awk '{print $2}')
    local intel_bar; intel_bar=$(make_bar "${intel_load:-0}" 100)
    local intel_col; intel_col=$(color_by_level "${intel_load:-0}" 60 85)
    echo -e "  Intel Load   : ${intel_col}${BOLD}${intel_load:-0.00}%${NC}  ${intel_col}${intel_bar}${NC}  ${DIM}(Render/3D)${NC}"
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"
}

section_top_procs() {
    echo -e "${BLUE}${BOLD}┌─ TOP PROCESSES (by CPU) ───────────────────────┐${NC}"
    printf "  ${BOLD}%-6s %-22s %-6s %-6s${NC}\n" "PID" "NAME" "CPU%" "MEM%"
    ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6 {printf "  %-6s %-22s %-6s %-6s\n", $2, substr($11,1,22), $3, $4}'
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────┘${NC}\n"
}

main() {
    clear
    check_sudo
    print_header
    section_hardware
    section_thermal
    section_battery
    section_storage_thermal
    section_memory
    section_storage_usage
    section_security
    section_gpu
    section_top_procs
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
    echo -e "${DIM}  Selesai: $(date '+%H:%M:%S')${NC}\n"
    read -rp "  Tekan Enter untuk keluar..."
}

main
