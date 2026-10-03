# Ringkasan Catatan: Hyprland SDDM Login Loop

Dokumentasi ini disimpan agar asisten dapat langsung membaca konteks jika sesi baru dimulai.

- **Masalah:** Kembali ke layar login SDDM setelah reboot.
- **Penyebab:** Delimiter `:` pada `AQ_DRM_DEVICES` memecah alamat PCI `/dev/dri/by-path/pci-0000:00:02.0-card:...` sehingga Aquamarine gagal menemukan GPU dan Hyprland coredump saat startup.
- **Solusi yang Diterapkan:** Dikembalikan ke format `env = AQ_DRM_DEVICES,/dev/dri/card2:/dev/dri/card1` di `~/.config/hypr/configs/ENVariables.conf`.
- **Jika masih ada masalah:** 
  1. Komentari baris `AQ_DRM_DEVICES` (beri `#`) agar Aquamarine otomatis mendeteksi display aktif.
  2. Buka TTY (`Ctrl+Alt+F3`) dan jalankan `Hyprland` langsung untuk membaca log.
