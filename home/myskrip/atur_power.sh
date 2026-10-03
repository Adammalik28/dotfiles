#!/bin/bash
# ╔════════════════════════════════════════╗
# ║      power-manager.sh — CPU & Baterai   ║
# ║      by Adam | Hyprland Setup           ║
# ╚════════════════════════════════════════╝
#
# Untuk Arch Linux + Hyprland (Intel CPU dengan intel_pstate)
#
# Perbaikan dari versi sebelumnya:
#   - Cek dependency di awal, tidak gagal diam-diam
#   - sudo di-cache sekali di awal (keepalive), tidak minta password berulang
#   - Fallback frekuensi maksimum yang masuk akal (bukan 9999999 kHz)
#   - Validasi EPP terhadap daftar yang benar-benar didukung hardware
#   - Deteksi baterai tanpa hardcode path (BAT1) yang mungkin tak ada
#   - Bisa dipanggil langsung dengan argumen: power-manager.sh 1|2|3|4
#     (cocok untuk keybinding Hyprland, tanpa perlu menu interaktif)
#   - Log otomatis dirotasi agar tidak membengkak
#   - nbfc & notify-send bersifat opsional (tidak wajib terinstal)
#   - Tampilan diselaraskan dengan atur.sh: palet warna sama, border rounded,
#     dan menu-nya sekarang picker fzf (bukan menu angka yang clear layar
#     tiap putaran) — supaya transisi dari atur.sh terasa menyatu, tidak
#     terasa "tampilan hilang". fzf opsional: kalau tidak ada, otomatis
#     fallback ke menu angka klasik.
#   - FIX: di menu fzf, setelah menjalankan sebuah opsi (termasuk "Cek
#     Status"), loop langsung memanggil fzf lagi yang mengambil alih layar
#     sehingga output opsi tsb langsung "hilang" sebelum sempat dibaca —
#     inilah sebabnya "Cek Status" terkesan tidak berfungsi. Sekarang ada
#     jeda "Tekan Enter" setelah setiap opsi dijalankan.
#   - Cek Status sekarang menampilkan laporan sistem lengkap: info sistem
#     & uptime, CPU (model/governor/freq/turbo/EPP), suhu, memori, GPU,
#     disk, dan baterai.
# ========================================

set -uo pipefail

# ---------------------------------------
# KONFIGURASI
# ---------------------------------------
CPU_PATH="/sys/devices/system/cpu"
PSTATE_PATH="/sys/devices/system/cpu/intel_pstate"
LOG_FILE="$HOME/.power-manager.log"
LOG_MAX_LINES=500
STATE_FILE="$HOME/.power-manager.state"   # menyimpan profil aktif terakhir

# Path absolut ke diri sendiri, dipakai fzf untuk memanggil preview status
SELF="$(readlink -f "$0" 2>/dev/null || echo "$0")"

# ─── Warna (sama seperti atur.sh, dimatikan otomatis kalau output bukan terminal) ───
# PENTING: gunakan ANSI-C quoting $'...' supaya isi variabel adalah BYTE ESC
# sungguhan (0x1B), bukan teks literal "\033". Kalau pakai '...' biasa,
# `echo -e` kebetulan tetap bisa menerjemahkannya, TAPI `printf '%s'`
# (dipakai di menu fzf) tidak akan menerjemahkannya — hasilnya teks mentah
# "\033[2m" muncul di layar alih-alih benar-benar berwarna redup.
if [ -t 1 ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

get_active_profile() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "Belum diatur"
    fi
}

set_active_profile() {
    echo "$1" > "$STATE_FILE"
}

# ---------------------------------------
# UTILITAS DASAR
# ---------------------------------------

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [POWER-MANAGER] $1" >> "$LOG_FILE"
}

rotate_log() {
    [ -f "$LOG_FILE" ] || return 0
    local lines
    lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$lines" -gt "$LOG_MAX_LINES" ]; then
        tail -n "$LOG_MAX_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

notify() {
    # notify-send opsional — jangan sampai skrip berhenti kalau tidak ada
    if has_cmd notify-send; then
        notify-send "Power Manager" "$1"
    fi
    echo "$1"
}

check_deps() {
    local missing=()
    for dep in upower awk; do
        has_cmd "$dep" || missing+=("$dep")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Peringatan:${RESET} dependency berikut tidak ditemukan: ${missing[*]}" >&2
        echo "Beberapa fitur (status baterai) mungkin tidak berfungsi." >&2
    fi
    if ! has_cmd powerprofilesctl; then
        echo -e "${YELLOW}Peringatan:${RESET} powerprofilesctl tidak ditemukan (paket power-profiles-daemon)." >&2
    fi
    if ! has_cmd fzf; then
        echo -e "${YELLOW}Info:${RESET} fzf tidak ditemukan, memakai menu angka klasik. Install dengan: ${CYAN}sudo pacman -S fzf${RESET}" >&2
    fi
    if ! has_cmd sensors; then
        echo -e "${YELLOW}Info:${RESET} lm_sensors tidak ditemukan, suhu akan dibaca dari /sys/class/thermal saja. Install dengan: ${CYAN}sudo pacman -S lm_sensors${RESET}" >&2
    fi
}

# Sudo diminta LAZY (baru saat operasi pertama yang butuh root, bukan di awal
# skrip tanpa syarat) supaya "Cek Status" (opsi 4, murni baca) tidak pernah
# memaksa user memasukkan password. Dipanggil dari dalam set_epp/set_max_freq_*/
# set_turbo, dan hanya benar-benar minta password sekali (SUDO_ACQUIRED sebagai guard).
SUDO_ACQUIRED=0
ensure_sudo() {
    [ "$SUDO_ACQUIRED" -eq 1 ] && return 0
    if ! sudo -v; then
        echo "Gagal mendapatkan hak akses sudo." >&2
        return 1
    fi
    # Perpanjang timestamp sudo di background selama skrip masih hidup.
    # Interval dipersingkat ke 5 detik (dari 60 detik) supaya kalau proses induk
    # mati mendadak (SIGKILL), cache sudo tidak "nyantol" lama-lama di background.
    ( while true; do sudo -n true; sleep 5; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
    SUDO_ACQUIRED=1
}

sudo_keepalive_stop() {
    [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
}

trap sudo_keepalive_stop EXIT

# ---------------------------------------
# FUNGSI CPU / FREKUENSI / EPP / TURBO
# ---------------------------------------

# Ambil EPP yang diminta, tapi jatuhkan ke pilihan valid terdekat kalau tidak didukung
validate_epp() {
    local requested=$1
    local ref="$CPU_PATH/cpu0/cpufreq/energy_performance_available_preferences"
    if [ -f "$ref" ]; then
        if grep -qw "$requested" "$ref"; then
            echo "$requested"
            return 0
        else
            echo "Peringatan: EPP '$requested' tidak didukung. Pilihan tersedia: $(cat "$ref")" >&2
            # fallback ke 'balance_performance' kalau ada, kalau tidak ambil kata pertama
            if grep -qw "balance_performance" "$ref"; then
                echo "balance_performance"
            else
                awk '{print $1}' "$ref"
            fi
            return 0
        fi
    fi
    # Tidak ada file referensi -> tetap coba nilai yang diminta
    echo "$requested"
}

set_epp() {
    ensure_sudo || return 1
    local mode
    mode=$(validate_epp "$1")
    local changed=0
    for cpu in "$CPU_PATH"/cpu[0-9]*; do
        if [ -f "$cpu/cpufreq/energy_performance_preference" ]; then
            if echo "$mode" | sudo tee "$cpu/cpufreq/energy_performance_preference" >/dev/null 2>&1; then
                changed=1
            fi
        fi
    done
    if [ $changed -eq 0 ]; then
        echo "Peringatan: energy_performance_preference tidak ditemukan (bukan Intel pstate?)." >&2
    fi
}

set_max_freq() {
    ensure_sudo || return 1
    local freq=$1  # dalam kHz

    # Klem ke batas hardware: profil punya nilai hardcode (1.2GHz/2.5GHz) yang
    # bisa saja lebih tinggi dari cpuinfo_max_freq CPU tertentu. Kalau begitu,
    # kernel menolak tulisan tersebut dan sebelumnya gagal diam-diam (>&1
    # dibuang), sehingga max_freq tidak berubah sama sekali tanpa peringatan.
    local hw_max
    hw_max=$(get_hw_max_freq)
    if [ "$hw_max" -gt 0 ] 2>/dev/null && [ "$freq" -gt "$hw_max" ] 2>/dev/null; then
        echo "Peringatan: freq diminta ($((freq / 1000)) MHz) melebihi batas hardware ($((hw_max / 1000)) MHz), memakai batas hardware." >&2
        freq=$hw_max
    fi

    for cpu in "$CPU_PATH"/cpu[0-9]*; do
        if [ -f "$cpu/cpufreq/scaling_max_freq" ]; then
            echo "$freq" | sudo tee "$cpu/cpufreq/scaling_max_freq" >/dev/null 2>&1
        fi
    done
}

# Kembalikan frekuensi maksimum hardware (kHz). Cari di semua core, ambil yang terbesar.
get_hw_max_freq() {
    local max=0
    for f in "$CPU_PATH"/cpu[0-9]*/cpufreq/cpuinfo_max_freq; do
        [ -f "$f" ] || continue
        local val
        val=$(cat "$f" 2>/dev/null || echo 0)
        if [ "$val" -gt "$max" ] 2>/dev/null; then
            max=$val
        fi
    done
    echo "$max"
}

set_unlimited_freq() {
    local max_freq
    max_freq=$(get_hw_max_freq)
    if [ "$max_freq" -gt 0 ] 2>/dev/null; then
        set_max_freq "$max_freq"
        echo "Frekuensi maksimum diatur ke batas hardware: $((max_freq / 1000)) MHz"
    else
        echo "Peringatan: Tidak dapat menentukan frekuensi maksimum hardware. Freq tidak diubah." >&2
    fi
}

set_turbo() {
    ensure_sudo || return 1
    local state=$1  # 0 = ON, 1 = OFF
    if [ -f "$PSTATE_PATH/no_turbo" ]; then
        echo "$state" | sudo tee "$PSTATE_PATH/no_turbo" >/dev/null 2>&1
    else
        echo "Peringatan: intel_pstate/no_turbo tidak ditemukan (mungkin CPU non-Intel atau EPP driver berbeda)." >&2
    fi
}

set_fan() {
    # nbfc opsional — banyak laptop Arch tidak memakainya
    local mode=$1  # "auto" atau "5"
    if ! has_cmd nbfc; then
        return 0
    fi
    if [ "$mode" = "auto" ]; then
        nbfc set -a >/dev/null 2>&1
    else
        nbfc set -s "$mode" >/dev/null 2>&1
    fi
}

# ---------------------------------------
# BATERAI & STATUS
# ---------------------------------------

get_battery_path() {
    local bp
    bp=$(upower -e 2>/dev/null | grep -m1 battery)
    echo "$bp"   # bisa kosong; caller wajib cek
}

is_on_ac() {
    # 0 = di charger, 1 = di baterai, 2 = tidak diketahui
    #
    # PENTING: jangan cocokkan dengan substring "charging" saja — string
    # "discharging" JUGA mengandung "charging" di dalamnya, sehingga regex
    # lama ("state:.*charging") salah mendeteksi baterai yang sedang
    # discharging sebagai charging. Di sini kita ambil nilai field "state:"
    # secara utuh lalu bandingkan persis.
    if has_cmd upower; then
        local bp
        bp=$(get_battery_path)
        if [ -n "$bp" ]; then
            local state
            state=$(upower -i "$bp" 2>/dev/null \
                | awk -F': *' '/^[[:space:]]*state:/ {print $2; exit}')
            case "$state" in
                charging|fully-charged) return 0 ;;
                *) return 1 ;;
            esac
        fi
    fi
    return 2
}

# ---------------------------------------
# CEK STATUS — laporan sistem lengkap
# ---------------------------------------

status_section_sistem() {
    echo -e "${BOLD}${CYAN}── Sistem ───────────────────────────────────${RESET}"
    local hostname_val kernel_val uptime_val loadavg_val
    hostname_val=$(hostname 2>/dev/null || echo "N/A")
    kernel_val=$(uname -sr 2>/dev/null || echo "N/A")
    uptime_val=$(uptime -p 2>/dev/null || echo "N/A")
    printf "  %-16s: %s\n" "Hostname" "$hostname_val"
    printf "  %-16s: %s\n" "Kernel" "$kernel_val"
    printf "  %-16s: %s\n" "Uptime" "$uptime_val"
    if [ -r /proc/loadavg ]; then
        loadavg_val=$(awk '{print $1", "$2", "$3}' /proc/loadavg)
        printf "  %-16s: %s\n" "Load average" "$loadavg_val"
    fi
}

status_section_cpu() {
    echo -e "${BOLD}${CYAN}── CPU ──────────────────────────────────────${RESET}"

    local cpu_model
    cpu_model=$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null)
    [ -n "$cpu_model" ] && printf "  %-16s: %s\n" "Model" "$cpu_model"

    # Ringkas: tampilkan rentang freq semua core dalam satu baris, bukan per-core
    # (per-core cuma ditampilkan kalau govenor/freq TIDAK seragam)
    local governors=() freqs=()
    for CPU_DIR in "$CPU_PATH"/cpu[0-9]*; do
        governors+=("$(cat "$CPU_DIR/cpufreq/scaling_governor" 2>/dev/null || echo "N/A")")
        if [ -f "$CPU_DIR/cpufreq/scaling_cur_freq" ]; then
            freqs+=("$(($(cat "$CPU_DIR/cpufreq/scaling_cur_freq") / 1000))")
        fi
    done

    printf "  %-16s: %s\n" "Jumlah core" "${#governors[@]}"

    if [ ${#governors[@]} -gt 0 ]; then
        local uniq_gov
        uniq_gov=$(printf "%s\n" "${governors[@]}" | sort -u)
        if [ "$(echo "$uniq_gov" | wc -l)" -eq 1 ]; then
            printf "  %-16s: %s\n" "Governor" "$uniq_gov"
        else
            printf "  %-16s: %s\n" "Governor" "campuran ($(echo "$uniq_gov" | tr '\n' '/'))"
        fi
    fi

    if [ ${#freqs[@]} -gt 0 ]; then
        local min max
        min=$(printf "%s\n" "${freqs[@]}" | sort -n | head -1)
        max=$(printf "%s\n" "${freqs[@]}" | sort -n | tail -1)
        printf "  %-16s: %s - %s MHz\n" "Freq saat ini" "$min" "$max"
    fi

    local hw_max
    hw_max=$(get_hw_max_freq)
    [ "$hw_max" -gt 0 ] 2>/dev/null && printf "  %-16s: %s MHz\n" "Freq maks hw" "$((hw_max / 1000))"

    if [ -f "$PSTATE_PATH/no_turbo" ]; then
        local TURBO_STATE
        TURBO_STATE=$(cat "$PSTATE_PATH/no_turbo")
        if [ "$TURBO_STATE" = "0" ]; then
            printf "  %-16s: ${GREEN}AKTIF${RESET}\n" "Turbo Boost"
        else
            printf "  %-16s: ${DIM}NONAKTIF${RESET}\n" "Turbo Boost"
        fi
    fi
    if [ -f "$CPU_PATH/cpu0/cpufreq/energy_performance_preference" ]; then
        printf "  %-16s: %s\n" "EPP (cpu0)" "$(cat "$CPU_PATH/cpu0/cpufreq/energy_performance_preference")"
    fi
}

# Baca baris dari stdin, warnai angka "+NN.N°C" sesuai ambang batas:
# hijau <70°C, kuning 70-84.9°C, merah >=85°C. Dipakai untuk output 'sensors'.
colorize_temps() {
    awk -v red="$RED" -v yellow="$YELLOW" -v green="$GREEN" -v reset="$RESET" '
    {
        line = $0
        if (match(line, /[+-]?[0-9]+\.[0-9]+°C/)) {
            temp_str = substr(line, RSTART, RLENGTH)
            num = temp_str + 0
            color = green
            if (num >= 85) color = red
            else if (num >= 70) color = yellow
            line = substr(line, 1, RSTART-1) color temp_str reset substr(line, RSTART+RLENGTH)
        }
        print line
    }'
}

# Cetak satu baris suhu dengan warna sesuai ambang batas (dipakai untuk fallback thermal_zone)
print_temp_line() {
    local label=$1 temp_c=$2
    local color="$GREEN"
    if awk -v t="$temp_c" 'BEGIN{exit !(t>=85)}'; then
        color="$RED"
    elif awk -v t="$temp_c" 'BEGIN{exit !(t>=70)}'; then
        color="$YELLOW"
    fi
    printf "  %-16s: ${color}%s°C${RESET}\n" "$label" "$temp_c"
}

status_section_suhu() {
    echo -e "${BOLD}${CYAN}── Suhu ─────────────────────────────────────${RESET}"
    if has_cmd sensors; then
        local out
        out=$(sensors 2>/dev/null | grep -E "Core|Package|Tctl|Tdie|temp1")
        if [ -n "$out" ]; then
            echo "$out" | colorize_temps | sed 's/^/  /'
        else
            echo "  Tidak ada data suhu dari 'sensors'."
        fi
    else
        local tz_found=0
        for tz in /sys/class/thermal/thermal_zone*; do
            [ -d "$tz" ] || continue
            local type temp
            type=$(cat "$tz/type" 2>/dev/null)
            temp=$(cat "$tz/temp" 2>/dev/null)
            if [ -n "$temp" ] && [ "$temp" -gt 0 ] 2>/dev/null; then
                print_temp_line "$type" "$(awk -v t="$temp" 'BEGIN{printf "%.1f", t/1000}')"
                tz_found=1
            fi
        done
        [ "$tz_found" -eq 0 ] && echo "  Tidak ada data suhu (install lm_sensors: sudo pacman -S lm_sensors, lalu jalankan 'sudo sensors-detect')."
    fi
}

status_section_memori() {
    echo -e "${BOLD}${CYAN}── Memori ───────────────────────────────────${RESET}"
    if has_cmd free; then
        free -h | sed 's/^/  /'

        # Peringatan kalau swap terpakai signifikan (>30%) — indikasi tekanan memori
        local swap_total swap_used
        swap_total=$(free -m 2>/dev/null | awk '/^Swap:/{print $2}')
        swap_used=$(free -m 2>/dev/null | awk '/^Swap:/{print $3}')
        if [ -n "$swap_total" ] && [ "$swap_total" -gt 0 ] 2>/dev/null; then
            local pct
            pct=$(awk -v u="$swap_used" -v t="$swap_total" 'BEGIN{printf "%.0f", (u/t)*100}')
            if [ "$pct" -ge 30 ] 2>/dev/null; then
                echo -e "  ${YELLOW}⚠ Swap terpakai ${pct}% — kemungkinan RAM sedang tertekan.${RESET}"
            fi
        fi
    else
        echo "  'free' tidak ditemukan."
    fi
}

status_section_gpu() {
    echo -e "${BOLD}${CYAN}── GPU ──────────────────────────────────────${RESET}"
    local found=0
    if has_cmd lspci; then
        local gpu_lines
        gpu_lines=$(lspci 2>/dev/null | grep -Ei "vga|3d controller|display controller")
        if [ -n "$gpu_lines" ]; then
            echo "$gpu_lines" | sed -E 's/^[0-9a-f:.]+ //' | sed 's/^/  /'
            found=1
        fi
    fi
    if [ "$found" -eq 0 ]; then
        echo "  Tidak dapat mendeteksi GPU (lspci tidak ada atau tidak menemukan device)."
    fi

    # Frekuensi GPU Intel (i915) kalau tersedia
    local gt_freq
    for gt_freq in /sys/class/drm/card[0-9]/gt_cur_freq_mhz; do
        [ -f "$gt_freq" ] || continue
        printf "  %-16s: %s MHz\n" "GPU freq saat ini" "$(cat "$gt_freq" 2>/dev/null)"
    done
    for gt_freq in /sys/class/drm/card[0-9]/gt_max_freq_mhz; do
        [ -f "$gt_freq" ] || continue
        printf "  %-16s: %s MHz\n" "GPU freq maks" "$(cat "$gt_freq" 2>/dev/null)"
    done

    # dGPU NVIDIA (laptop hybrid) — dGPU yang tetap aktif/tidak suspend adalah
    # salah satu penyebab boros baterai terbesar, jadi ini penting ditampilkan.
    if has_cmd nvidia-smi; then
        local nv_out
        nv_out=$(nvidia-smi --query-gpu=name,temperature.gpu,power.draw,utilization.gpu,memory.used,memory.total \
            --format=csv,noheader,nounits 2>/dev/null)
        if [ -n "$nv_out" ]; then
            echo -e "  ${GREEN}NVIDIA: AKTIF${RESET}"
            echo "$nv_out" | while IFS=',' read -r name temp power util mem_used mem_total; do
                printf "  %-16s: %s\n" "  Model" "$(echo "$name" | sed 's/^ *//')"
                printf "  %-16s: %s°C\n" "  Suhu" "$(echo "$temp" | sed 's/^ *//')"
                printf "  %-16s: %s W\n" "  Power draw" "$(echo "$power" | sed 's/^ *//')"
                printf "  %-16s: %s%%\n" "  Utilisasi" "$(echo "$util" | sed 's/^ *//')"
                printf "  %-16s: %s / %s MiB\n" "  VRAM" "$(echo "$mem_used" | sed 's/^ *//')" "$(echo "$mem_total" | sed 's/^ *//')"
            done
        else
            echo -e "  ${DIM}NVIDIA: tidak merespons via nvidia-smi (kemungkinan sedang suspend/D3)${RESET}"
        fi
    elif lspci 2>/dev/null | grep -qi nvidia; then
        # Ada device NVIDIA tapi driver/nvidia-smi tidak tersedia — cek status runtime PM
        local nv_pm
        nv_pm=$(for f in /sys/bus/pci/devices/*/vendor; do
                    [ "$(cat "$f" 2>/dev/null)" = "0x10de" ] && dirname "$f"
                done | head -1)
        if [ -n "$nv_pm" ] && [ -f "$nv_pm/power/runtime_status" ]; then
            local rstat
            rstat=$(cat "$nv_pm/power/runtime_status" 2>/dev/null)
            case "$rstat" in
                suspended) echo -e "  ${GREEN}NVIDIA: suspended (hemat daya, driver terinstal)${RESET}" ;;
                active) echo -e "  ${YELLOW}NVIDIA: aktif tapi nvidia-smi tidak ada${RESET}" ;;
                *) echo -e "  ${DIM}NVIDIA: status runtime tidak diketahui ($rstat)${RESET}" ;;
            esac
        else
            echo -e "  ${DIM}NVIDIA: terdeteksi di lspci tapi driver nvidia-smi tidak ditemukan${RESET}"
        fi
    fi
}

status_section_kipas() {
    if ! has_cmd nbfc; then
        return 0
    fi
    echo -e "${BOLD}${CYAN}── Kipas (nbfc) ─────────────────────────────${RESET}"
    local nb_out
    nb_out=$(nbfc status 2>/dev/null)
    if [ -n "$nb_out" ]; then
        echo "$nb_out" | sed 's/^/  /'
    else
        echo "  Tidak bisa membaca status nbfc (daemon belum jalan?)."
    fi
}

status_section_disk() {
    echo -e "${BOLD}${CYAN}── Disk ─────────────────────────────────────${RESET}"
    if has_cmd df; then
        df -h -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | sed 's/^/  /'
    else
        echo "  'df' tidak ditemukan."
    fi
}

status_section_baterai() {
    echo -e "${BOLD}${CYAN}── Baterai ──────────────────────────────────${RESET}"
    if has_cmd upower; then
        local BAT_PATH
        BAT_PATH=$(get_battery_path)
        if [ -n "$BAT_PATH" ]; then
            upower -i "$BAT_PATH" \
                | grep -E "state|percentage|energy-rate|energy |energy-full|capacity|time to empty|time to full" \
                | sed 's/^[[:space:]]*/  /'
        else
            echo "  Tidak ditemukan perangkat baterai (mungkin desktop)."
        fi
    else
        echo "  upower tidak terinstal, status baterai dilewati."
    fi
}

cek_status() {
    status_section_sistem
    echo ""
    status_section_cpu
    echo ""
    status_section_suhu
    echo ""
    status_section_memori
    echo ""
    status_section_gpu
    echo ""
    status_section_disk
    echo ""
    status_section_baterai
    echo -e "${BOLD}${CYAN}────────────────────────────────────────────${RESET}"
}

# ---------------------------------------
# PROFIL
# ---------------------------------------

profile_power_saver() {
    has_cmd powerprofilesctl && powerprofilesctl set power-saver
    set_epp power
    set_max_freq 1200000
    set_turbo 1
    set_fan 5
    notify "Power Saver Aktif (Limit 1.2GHz, Turbo OFF)"
    log_action "Power-Saver mode activated"
    set_active_profile "Power-Saver"
}

profile_balanced() {
    has_cmd powerprofilesctl && powerprofilesctl set balanced
    set_epp balance_performance
    set_max_freq 2500000
    set_turbo 1
    set_fan 5
    notify "Balanced Aktif (Adaptive Mode, Turbo tersedia tapi dikontrol governor)"
    log_action "Balanced mode activated"
    set_active_profile "Balanced"
}

profile_performance() {
    has_cmd powerprofilesctl && powerprofilesctl set performance
    set_epp performance
    set_unlimited_freq
    set_turbo 0
    set_fan auto
    notify "Performance Aktif (Turbo ON, Fan Auto, Max Freq)"
    log_action "Performance mode activated"
    set_active_profile "Performance"
}

# ---------------------------------------
# BANNER (gaya sama seperti atur.sh)
# ---------------------------------------

show_banner() {
    local active
    active=$(get_active_profile)
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║   Power Manager - Arch Linux + Hyprland ║${RESET}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════╝${RESET}"
    echo -e "  Profil aktif saat ini: ${GREEN}${BOLD}${active}${RESET}"
    echo ""
}

# ---------------------------------------
# MENU — FZF (dipakai kalau fzf tersedia)
# ---------------------------------------
# Sengaja TIDAK memanggil `clear` sama sekali (sama seperti atur.sh), supaya
# output sebelumnya (termasuk tampilan atur.sh yang memanggil skrip ini)
# tetap terlihat menggulir ke atas, bukan hilang tiba-tiba.

run_choice() {
    case "$1" in
        1) profile_power_saver ;;
        2) profile_balanced ;;
        3) profile_performance ;;
        4) cek_status ;;
        *) echo "Pilihan tidak valid: $1" >&2; return 1 ;;
    esac
}

menu_fzf() {
    show_banner

    local options=(
        "1  Power-Saver   ${DIM}(Ultra Hemat, 1.2GHz, Turbo OFF)${RESET}"
        "2  Balanced      ${DIM}(Harian, Adaptive)${RESET}"
        "3  Performance   ${DIM}(Full Power, Turbo ON)${RESET}"
        "4  Cek Status"
        "5  Keluar"
    )

    while true; do
        local active
        active=$(get_active_profile)

        local choice
        choice=$(printf '%s\n' "${options[@]}" | fzf \
            --ansi \
            --height 60% \
            --layout=reverse \
            --border=rounded \
            --prompt="Pilih Profil: " \
            --pointer=">" \
            --info=inline \
            --header=" Enter=pilih | Ctrl-C=keluar | Aktif: $active" \
            --preview "\"$SELF\" __preview_status" \
            --preview-window=right:55%:wrap \
            --color="header:italic,border:#7aa2f7,prompt:#7dcfff,pointer:#f7768e")

        if [ -z "$choice" ]; then
            echo -e "${YELLOW}Dibatalkan.${RESET}"
            break
        fi

        local num="${choice%% *}"

        if [ "$num" = "5" ]; then
            echo "Keluar."
            break
        fi

        echo ""
        echo -e "${CYAN}Menjalankan:${RESET} ${BOLD}$(echo "$choice" | sed -E 's/\x1b\[[0-9;]*m//g')${RESET}"
        echo "─────────────────────────────────────────"
        run_choice "$num"
        echo "─────────────────────────────────────────"
        # FIX: tanpa jeda ini, loop langsung memanggil fzf lagi yang mengambil
        # alih layar sehingga output di atas (terutama Cek Status yang panjang)
        # langsung "hilang" sebelum sempat dibaca — inilah bug yang membuat
        # opsi Cek Status terasa tidak berfungsi.
        read -rp $'\nTekan Enter untuk kembali ke menu...' _
        echo ""
    done
}

# ---------------------------------------
# MENU — Klasik (fallback kalau fzf tidak ada)
# ---------------------------------------

menu_classic() {
    local last_message=""
    while true; do
        clear
        show_banner

        local active
        active=$(get_active_profile)
        mark() { [ "$active" = "$1" ] && echo -e "${GREEN}●${RESET}" || echo " "; }

        echo -e "  $(mark "Power-Saver") 1. Power-Saver   ${DIM}(Ultra Hemat, 1.2GHz, Turbo OFF)${RESET}"
        echo -e "  $(mark "Balanced")    2. Balanced      ${DIM}(Harian, Adaptive)${RESET}"
        echo -e "  $(mark "Performance") 3. Performance   ${DIM}(Full Power, Turbo ON)${RESET}"
        echo -e "     4. Cek Status"
        echo -e "     5. Keluar"
        echo ""

        if [ -n "$last_message" ]; then
            echo -e "${YELLOW}➜ ${last_message}${RESET}"
            echo ""
        fi

        read -rp "Pilih [1-5]: " pil

        case "$pil" in
            5) echo "Keluar."; break ;;
            1) last_message=$(run_choice 1 2>&1 | tail -1) ;;
            2) last_message=$(run_choice 2 2>&1 | tail -1) ;;
            3) last_message=$(run_choice 3 2>&1 | tail -1) ;;
            4)
                clear
                cek_status
                read -rp $'\nTekan Enter untuk kembali ke menu...' _
                last_message=""
                ;;
            *) last_message="Pilihan tidak valid: $pil" ;;
        esac
    done
}

# ════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════

main() {
    # Sub-perintah tersembunyi dipakai oleh preview pane fzf untuk
    # menampilkan status live tanpa ikut memicu sudo/keepalive/dsb.
    if [ "${1:-}" = "__preview_status" ]; then
        cek_status
        exit 0
    fi

    check_deps
    rotate_log

    # Mode non-interaktif: power-manager.sh 1|2|3|4
    if [ $# -ge 1 ]; then
        run_choice "$1"
        exit $?
    fi

    # Mode interaktif: fzf kalau ada, kalau tidak pakai menu angka klasik
    if has_cmd fzf; then
        menu_fzf
    else
        menu_classic
    fi
}

main "$@"