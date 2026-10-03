#!/bin/bash
# service.sh — Manajemen systemd service via fzf
# Oleh: myskrip collection

NOTIF_TIMEOUT=4000

notif() {
    notify-send -t "$NOTIF_TIMEOUT" "⚙️ Service Manager" "$1"
}

aksi_service() {
    local svc="$1"
    local is_user="${2:-0}"
    local ctl="sudo systemctl"
    local jctl="journalctl"
    [ "$is_user" -eq 1 ] && ctl="systemctl --user" && jctl="journalctl --user"

    local aksi
    aksi=$(printf "▶  start\n⏹  stop\n🔄  restart\n🔃  reload\n✅  enable\n❌  disable\n📋  status\n📜  log (journalctl)" \
        | fzf --prompt="Aksi untuk $svc > " \
              --height=50% \
              --border=rounded \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244 \
              | awk '{print $2}')

    [ -z "$aksi" ] && return

    case "$aksi" in
        start)    $ctl start "$svc"   && notif "$svc berhasil distart" ;;
        stop)     $ctl stop "$svc"    && notif "$svc berhasil distop" ;;
        restart)  $ctl restart "$svc" && notif "$svc berhasil direstart" ;;
        reload)   $ctl reload "$svc"  && notif "$svc berhasil direload" ;;
        enable)   $ctl enable "$svc"  && notif "$svc di-enable" ;;
        disable)  $ctl disable "$svc" && notif "$svc di-disable" ;;
        status)   $ctl status "$svc" | less ;;
        log|"(journalctl)")
            $jctl -u "$svc" -n 100 --no-pager | less ;;
    esac
}

main() {
    local filter="$1"  # "all", "running", "failed", "user" — default running
    local is_user=0
    local fzf_prompt="Service > "
    local svc_list

    case "$filter" in
        all)
            fzf_prompt="Semua Service > "
            svc_list=$(systemctl list-units --type=service --all --no-legend --no-pager \
                | awk '{print $1, $3, $4}')
            ;;
        failed)
            fzf_prompt="Service Gagal > "
            svc_list=$(systemctl list-units --type=service --state=failed --no-legend --no-pager \
                | awk '{print $1, $3, $4}')
            ;;
        user)
            is_user=1
            fzf_prompt="User Service > "
            svc_list=$(systemctl --user list-units --type=service --no-legend --no-pager \
                | awk '{print $1, $3, $4}')
            ;;
        *)
            fzf_prompt="Service Aktif > "
            svc_list=$(systemctl list-units --type=service --state=running --no-legend --no-pager \
                | awk '{print $1, $3, $4}')
            ;;
    esac

    if [ -z "$svc_list" ]; then
        notify-send -t "$NOTIF_TIMEOUT" "⚙️ Service Manager" "Tidak ada service ditemukan."
        exit 0
    fi

    local preview_cmd="systemctl status {1} 2>/dev/null | head -30"
    [ "$is_user" -eq 1 ] && preview_cmd="systemctl --user status {1} 2>/dev/null | head -30"

    local pilihan
    pilihan=$(echo "$svc_list" \
        | fzf --prompt="$fzf_prompt" \
              --height=60% \
              --border=rounded \
              --header="Enter=pilih aksi | Esc/Ctrl-C=batal" \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244,header:#a6e3a1 \
              --preview="$preview_cmd" \
              --preview-window=right:50%:wrap \
        | awk '{print $1}')

    [ -z "$pilihan" ] && exit 0

    aksi_service "$pilihan" "$is_user"
}

# Parse argumen
case "$1" in
    -a|--all)    main "all" ;;
    -f|--failed) main "failed" ;;
    -u|--user)   main "user" ;;
    -h|--help)
        echo "Penggunaan: service.sh [OPSI]"
        echo "  (tanpa opsi)   Tampilkan service yang sedang running"
        echo "  -a, --all      Tampilkan semua service sistem"
        echo "  -f, --failed   Tampilkan service yang gagal"
        echo "  -u, --user     Tampilkan service level user (pipewire, swaync, dll)"
        echo "  -h, --help     Tampilkan bantuan ini"
        ;;
    *)           main "running" ;;
esac
