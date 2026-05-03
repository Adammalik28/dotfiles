#!/bin/bash
# service.sh — Manajemen systemd service via fzf
# Oleh: myskrip collection

NOTIF_TIMEOUT=4000

notif() {
    notify-send -t "$NOTIF_TIMEOUT" "⚙️ Service Manager" "$1"
}

aksi_service() {
    local svc="$1"
    local aksi
    aksi=$(printf "▶  start\n⏹  stop\n🔄  restart\n🔃  reload\n✅  enable\n❌  disable\n📋  status\n📜  log (journalctl)" \
        | fzf --prompt="Aksi untuk $svc > " \
              --height=50% \
              --border=rounded \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244 \
              | awk '{print $2}')

    [ -z "$aksi" ] && return

    case "$aksi" in
        start)    sudo systemctl start "$svc"   && notif "$svc berhasil distart" ;;
        stop)     sudo systemctl stop "$svc"    && notif "$svc berhasil distop" ;;
        restart)  sudo systemctl restart "$svc" && notif "$svc berhasil direstart" ;;
        reload)   sudo systemctl reload "$svc"  && notif "$svc berhasil direload" ;;
        enable)   sudo systemctl enable "$svc"  && notif "$svc di-enable" ;;
        disable)  sudo systemctl disable "$svc" && notif "$svc di-disable" ;;
        status)   systemctl status "$svc" | less ;;
        "(journalctl)")
            journalctl -u "$svc" -n 100 --no-pager | less ;;
    esac
}

main() {
    local filter="$1"  # "all", "running", "failed" — default running

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

    local pilihan
    pilihan=$(echo "$svc_list" \
        | fzf --prompt="$fzf_prompt" \
              --height=60% \
              --border=rounded \
              --header="TAB=pilih | Enter=aksi | Ctrl-C=batal" \
              --color=bg+:#1e1e2e,fg+:#cdd6f4,hl+:#89b4fa,border:#313244,header:#a6e3a1 \
              --preview="systemctl status {1} 2>/dev/null | head -30" \
              --preview-window=right:50%:wrap \
        | awk '{print $1}')

    [ -z "$pilihan" ] && exit 0

    aksi_service "$pilihan"
}

# Parse argumen
case "$1" in
    -a|--all)    main "all" ;;
    -f|--failed) main "failed" ;;
    -h|--help)
        echo "Penggunaan: service.sh [OPSI]"
        echo "  (tanpa opsi)   Tampilkan service yang sedang running"
        echo "  -a, --all      Tampilkan semua service"
        echo "  -f, --failed   Tampilkan service yang gagal"
        echo "  -h, --help     Tampilkan bantuan ini"
        ;;
    *)           main "running" ;;
esac
