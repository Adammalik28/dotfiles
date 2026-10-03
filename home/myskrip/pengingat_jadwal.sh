#!/usr/bin/env bash
#
# jadwal.sh — Manajer jadwal & pengingat notifikasi desktop
#
# Menu interaktif (fzf): Lihat Jadwal / Tambah Jadwal / Edit Jadwal
# Mode latar belakang:   jadwal.sh --daemon
#
set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="${0##*/}"
readonly VERSION="1.0.0"

readonly DATA_DIR="$HOME/.local/share/jadwal-kuliah"
readonly DATA_FILE="$DATA_DIR/jadwal.tsv"
readonly LOG_FILE="$DATA_DIR/jadwal.log"
readonly LOCK_FILE="$DATA_DIR/daemon.lock"

readonly FZF_COLORS="bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244,header:#a6e3a1"

# Nama hari: index 0 = "setiap hari", 1..7 mengikuti ISO (date +%u): 1=Senin ... 7=Minggu
readonly -a NAMA_HARI=("Setiap Hari" "Senin" "Selasa" "Rabu" "Kamis" "Jumat" "Sabtu" "Minggu")

# ══════════════════════════════════════════
#  UTIL
# ══════════════════════════════════════════

log() {
    local level="$1"; shift
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >> "$LOG_FILE"
}

cek_dependensi() {
    local missing=()
    for cmd in fzf date awk sort; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        echo "Perintah wajib tidak ditemukan: ${missing[*]}" >&2
        exit 1
    fi
}

setup() {
    mkdir -p "$DATA_DIR"
    [ -f "$DATA_FILE" ] || : > "$DATA_FILE"
}

nama_hari() {
    # nama_hari INDEX -> cetak nama hari
    echo "${NAMA_HARI[$1]}"
}

urgensi_label() {
    case "$1" in
        critical) echo "Penting" ;;
        *)        echo "Biasa" ;;
    esac
}

id_baru() {
    date +%s%N
}

urutkan_file() {
    # Urutkan berdasarkan hari (kolom 2) lalu jam (kolom 3)
    sort -t $'\t' -k2,2n -k3,3 -o "$DATA_FILE" "$DATA_FILE"
}

# Format satu baris data menjadi teks yang enak dibaca untuk ditampilkan.
format_baris() {
    local hari jam pesan urgensi
    IFS=$'\t' read -r _ hari jam pesan urgensi <<< "$1"
    printf '%-11s | %-5s | %-6s | %s' "$(nama_hari "$hari")" "$jam" "$(urgensi_label "$urgensi")" "$pesan"
}

# ══════════════════════════════════════════
#  VALIDASI INPUT
# ══════════════════════════════════════════

input_jam() {
    local jam
    while true; do
        read -rp "Jam notifikasi (format HH:MM, contoh 13:40): " jam
        if [[ "$jam" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            echo "$jam"
            return 0
        fi
        echo "Format jam tidak valid. Gunakan format 24 jam HH:MM." >&2
    done
}

input_pesan() {
    local pesan
    while true; do
        read -rp "Isi pesan notifikasi: " pesan
        pesan="${pesan#"${pesan%%[![:space:]]*}"}"   # trim spasi depan
        pesan="${pesan%"${pesan##*[![:space:]]}"}"   # trim spasi belakang
        if [ -n "$pesan" ]; then
            echo "$pesan"
            return 0
        fi
        echo "Pesan tidak boleh kosong." >&2
    done
}

pilih_hari() {
    local pilihan idx
    pilihan=$(for i in "${!NAMA_HARI[@]}"; do echo "$i	${NAMA_HARI[$i]}"; done \
        | fzf --delimiter=$'\t' --with-nth=2 \
              --prompt="Pilih hari > " \
              --height=50% --border=rounded --color="$FZF_COLORS" \
              --header="Pilih hari untuk jadwal ini")
    [ -z "$pilihan" ] && return 1
    idx="${pilihan%%$'\t'*}"
    echo "$idx"
}

pilih_urgensi() {
    local pilihan
    pilihan=$(printf 'normal\tBiasa\ncritical\tPenting (selalu tampil di layar)\n' \
        | fzf --delimiter=$'\t' --with-nth=2 \
              --prompt="Tingkat urgensi > " \
              --height=30% --border=rounded --color="$FZF_COLORS")
    [ -z "$pilihan" ] && { echo "normal"; return 0; }
    echo "${pilihan%%$'\t'*}"
}

# ══════════════════════════════════════════
#  3 OPSI UTAMA
# ══════════════════════════════════════════

lihat_jadwal() {
    if [ ! -s "$DATA_FILE" ]; then
        echo "Belum ada jadwal. Pilih 'Tambah Jadwal' untuk menambahkan."
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi

    local tampilan
    tampilan=$(while IFS= read -r baris; do
        [ -z "$baris" ] && continue
        format_baris "$baris"
        echo
    done < "$DATA_FILE")

    printf '%s\n' "$tampilan" \
        | fzf --prompt="Jadwal (Esc untuk kembali) > " \
              --height=80% --border=rounded --color="$FZF_COLORS" \
              --header="$(printf '%-11s | %-5s | %-6s | %s' Hari Jam Urgensi Pesan)" \
              --header-first \
              --no-sort > /dev/null || true
}

tambah_jadwal() {
    echo "═══ Tambah Jadwal Baru ═══"
    local hari jam pesan urgensi id

    hari=$(pilih_hari) || { echo "Dibatalkan."; return; }
    jam=$(input_jam)
    pesan=$(input_pesan)
    urgensi=$(pilih_urgensi)
    id=$(id_baru)

    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$hari" "$jam" "$pesan" "$urgensi" >> "$DATA_FILE"
    urutkan_file
    log "INFO" "Jadwal ditambahkan: $(nama_hari "$hari") $jam - $pesan"
    echo "✅ Jadwal berhasil ditambahkan: $(nama_hari "$hari"), $jam — \"$pesan\""
    read -rp "Tekan Enter untuk kembali..." _
}

pilih_entri() {
    # Menampilkan entri jadwal via fzf, mengembalikan baris TSV lengkap (termasuk id) yang dipilih.
    [ -s "$DATA_FILE" ] || return 1
    local dipilih
    dipilih=$(awk -F'\t' 'BEGIN{OFS="\t"} {print $0}' "$DATA_FILE" \
        | while IFS= read -r baris; do
            printf '%s\t%s\n' "$baris" "$(format_baris "$baris")"
        done \
        | fzf --delimiter=$'\t' --with-nth=6.. \
              --prompt="Pilih jadwal untuk diedit > " \
              --height=80% --border=rounded --color="$FZF_COLORS")
    [ -z "$dipilih" ] && return 1
    # Kembalikan hanya 5 kolom asli (id, hari, jam, pesan, urgensi)
    cut -f1-5 <<< "$dipilih"
}

edit_jadwal() {
    if [ ! -s "$DATA_FILE" ]; then
        echo "Belum ada jadwal untuk diedit."
        read -rp "Tekan Enter untuk kembali..." _
        return
    fi

    local entri id hari jam pesan urgensi
    entri=$(pilih_entri) || { echo "Dibatalkan."; return; }
    IFS=$'\t' read -r id hari jam pesan urgensi <<< "$entri"

    while true; do
        local aksi
        aksi=$(printf 'Ubah Jam\nUbah Pesan\nUbah Hari\nUbah Urgensi\nHapus Jadwal Ini\nSelesai\n' \
            | fzf --prompt="Aksi untuk: $(nama_hari "$hari") $jam — $pesan > " \
                  --height=40% --border=rounded --color="$FZF_COLORS")

        case "$aksi" in
            "Ubah Jam")     jam=$(input_jam) ;;
            "Ubah Pesan")   pesan=$(input_pesan) ;;
            "Ubah Hari")    hari=$(pilih_hari) || true ;;
            "Ubah Urgensi") urgensi=$(pilih_urgensi) ;;
            "Hapus Jadwal Ini")
                grep -v -F -x "$entri" "$DATA_FILE" > "$DATA_FILE.tmp" || true
                mv "$DATA_FILE.tmp" "$DATA_FILE"
                log "INFO" "Jadwal dihapus: $(nama_hari "$hari") $jam - $pesan"
                echo "🗑️  Jadwal dihapus."
                read -rp "Tekan Enter untuk kembali..." _
                return
                ;;
            "Selesai"|"")
                # Simpan perubahan (jika ada) ke baris lama
                local baris_baru
                baris_baru=$(printf '%s\t%s\t%s\t%s\t%s' "$id" "$hari" "$jam" "$pesan" "$urgensi")
                if [ "$baris_baru" != "$entri" ]; then
                    grep -v -F -x "$entri" "$DATA_FILE" > "$DATA_FILE.tmp" || true
                    echo "$baris_baru" >> "$DATA_FILE.tmp"
                    mv "$DATA_FILE.tmp" "$DATA_FILE"
                    urutkan_file
                    log "INFO" "Jadwal diedit -> $(nama_hari "$hari") $jam - $pesan"
                    echo "✅ Perubahan disimpan."
                else
                    echo "Tidak ada perubahan."
                fi
                read -rp "Tekan Enter untuk kembali..." _
                return
                ;;
        esac
        entri=$(printf '%s\t%s\t%s\t%s\t%s' "$id" "$hari" "$jam" "$pesan" "$urgensi")
    done
}

# ══════════════════════════════════════════
#  MODE DAEMON (pemantau latar belakang)
# ══════════════════════════════════════════

siapkan_sesi_desktop() {
    export DISPLAY="${DISPLAY:-:0}"
    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        local uid
        uid=$(id -u)
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus"
    fi
}

kirim_notif() {
    local pesan="$1" urgensi="${2:-normal}"
    if ! command -v notify-send >/dev/null 2>&1; then
        log "WARN" "notify-send tidak ditemukan, notifikasi dilewati: $pesan"
        return
    fi
    if notify-send -u "$urgensi" -i appointment-soon "PENGINGAT JADWAL" "$pesan" 2>>"$LOG_FILE"; then
        log "OK" "Notifikasi terkirim: $pesan"
    else
        log "FAIL" "Gagal mengirim notifikasi: $pesan"
    fi
}

cek_dan_kirim() {
    # Cek satu kali: bandingkan jadwal dengan waktu sekarang, kirim notifikasi yang cocok.
    [ -s "$DATA_FILE" ] || return 0

    local hari_ini jam_menit
    hari_ini=$(date +%u)      # 1=Senin ... 7=Minggu
    jam_menit=$(date +%H:%M)

    while IFS=$'\t' read -r _ hari jam pesan urgensi; do
        [ -z "${hari:-}" ] && continue
        if [ "$jam" = "$jam_menit" ] && { [ "$hari" = "0" ] || [ "$hari" = "$hari_ini" ]; }; then
            kirim_notif "$pesan" "$urgensi"
        fi
    done < "$DATA_FILE"
}

daemon() {
    setup
    siapkan_sesi_desktop

    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        echo "Daemon lain sudah berjalan (lock: $LOCK_FILE)." >&2
        exit 1
    fi

    log "INFO" "Daemon dimulai (PID $$)"
    echo "Skrip Aktif - Menunggu waktu yang tepat... (log: $LOG_FILE)"

    while true; do
        cek_dan_kirim
        # Tidur persis sampai awal menit berikutnya agar tiap jadwal
        # hanya dicek sekali per menit (mencegah notifikasi dobel).
        local detik_sekarang tidur
        detik_sekarang=$(date +%S)
        tidur=$(( 60 - 10#$detik_sekarang ))
        [ "$tidur" -le 0 ] && tidur=60
        sleep "$tidur"
    done
}

# ══════════════════════════════════════════
#  MENU & ENTRY POINT
# ══════════════════════════════════════════

tampilkan_hari_ini() {
    local hari_ini
    hari_ini=$(date +%u)      # 1=Senin ... 7=Minggu
    local nama_hari_ini="${NAMA_HARI[$hari_ini]}"

    echo -e "\033[0;34m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;34m║\033[0m   \033[1;33mJADWAL HARI INI: $nama_hari_ini ($(date '+%d %B %Y'))\033[0m"
    echo -e "\033[0;34m╚════════════════════════════════════════════════════════════════════════╝\033[0m"

    if [ ! -s "$DATA_FILE" ]; then
        echo "Belum ada jadwal tersimpan."
        return
    fi

    local ada=0
    printf "\033[1m%-8s | %-10s | %s\033[0m\n" "WAKTU" "URGENSI" "KEGIATAN / MATA KULIAH"
    echo "────────────────────────────────────────────────────────────────────────"
    while IFS=$'\t' read -r _ hari jam pesan urgensi; do
        [ -z "${hari:-}" ] && continue
        if [ "$hari" = "$hari_ini" ] || [ "$hari" = "0" ]; then
            ada=1
            local col="\033[0;32m"
            [ "$urgensi" = "critical" ] && col="\033[0;31m"
            printf "%-8s | ${col}%-10s\033[0m | %s\n" "$jam" "$(urgensi_label "$urgensi")" "$pesan"
        fi
    done < "$DATA_FILE"

    if [ "$ada" -eq 0 ]; then
        echo -e "\033[0;32mTidak ada jadwal kuliah/kegiatan hari ini! Relax ☕\033[0m"
    fi
    echo ""
}

tampilkan_semua_tabel() {
    echo -e "\033[0;34m╔════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;34m║\033[0m   \033[1;33mSEMUA JADWAL KULIAH & KEGIATAN\033[0m"
    echo -e "\033[0;34m╚════════════════════════════════════════════════════════════════════════╝\033[0m"

    if [ ! -s "$DATA_FILE" ]; then
        echo "Belum ada jadwal tersimpan."
        return
    fi

    printf "\033[1m%-12s | %-8s | %-10s | %s\033[0m\n" "HARI" "WAKTU" "URGENSI" "MATA KULIAH / KEGIATAN"
    echo "────────────────────────────────────────────────────────────────────────"
    while IFS=$'\t' read -r _ hari jam pesan urgensi; do
        [ -z "${hari:-}" ] && continue
        local col="\033[0;32m"
        [ "$urgensi" = "critical" ] && col="\033[0;31m"
        printf "%-12s | %-8s | ${col}%-10s\033[0m | %s\n" "$(nama_hari "$hari")" "$jam" "$(urgensi_label "$urgensi")" "$pesan"
    done < "$DATA_FILE"
    echo ""
}

tampilkan_bantuan() {
    cat <<EOF
$SCRIPT_NAME v$VERSION — Manajer jadwal & pengingat notifikasi

Penggunaan: $SCRIPT_NAME [OPSI]
  (tanpa opsi)   Menu interaktif: Lihat Jadwal / Tambah Jadwal / Edit Jadwal
  -t, --today    Tampilkan jadwal hari ini di terminal
  -l, --list     Tampilkan semua jadwal dalam tabel terminal
  --daemon       Jalankan pemantau latar belakang (kirim notifikasi sesuai jadwal)
  -v, --version  Tampilkan versi
  -h, --help     Tampilkan bantuan ini

Data jadwal disimpan di: $DATA_FILE
Log daemon disimpan di:  $LOG_FILE

Menjalankan daemon secara permanen (pilih salah satu):
  nohup $SCRIPT_NAME --daemon >/dev/null 2>&1 &
  # atau buat autostart di Hyprland: exec-once = ~/myskrip/pengingat_jadwal.sh --daemon
EOF
}

menu_interaktif() {
    while true; do
        local pilihan
        pilihan=$(printf '📋  Lihat Jadwal\n➕  Tambah Jadwal\n✏️  Edit Jadwal\n' \
            | fzf --prompt="Jadwal Manager > " \
                  --height=40% --border=rounded --color="$FZF_COLORS")

        case "$pilihan" in
            "📋  Lihat Jadwal")  lihat_jadwal ;;
            "➕  Tambah Jadwal") tambah_jadwal ;;
            "✏️  Edit Jadwal")   edit_jadwal ;;
            "")                  exit 0 ;;
        esac
    done
}

main() {
    cek_dependensi
    setup

    case "${1:-}" in
        --daemon)      daemon ;;
        -t|--today)    tampilkan_hari_ini ;;
        -l|--list)     tampilkan_semua_tabel ;;
        -v|--version)  echo "$SCRIPT_NAME v$VERSION" ;;
        -h|--help)     tampilkan_bantuan ;;
        "")            menu_interaktif ;;
        *)
            echo "Opsi tidak dikenal: $1" >&2
            tampilkan_bantuan
            exit 1
            ;;
    esac
}

main "$@"