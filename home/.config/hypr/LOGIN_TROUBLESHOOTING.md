# Ringkasan Catatan: Hyprland SDDM Login Loop

Dokumentasi ini disimpan agar asisten dapat langsung membaca konteks jika sesi baru dimulai.

- **Masalah:** Kembali ke layar login SDDM setelah reboot.
- **Penyebab:** Delimiter `:` pada `AQ_DRM_DEVICES` memecah alamat PCI `/dev/dri/by-path/pci-0000:00:02.0-card:...` sehingga Aquamarine gagal menemukan GPU dan Hyprland coredump saat startup.
- **Solusi yang Diterapkan:** Nilai `AQ_DRM_DEVICES` kini dihitung otomatis saat Hyprland dimuat: alamat PCI tetap (Intel 0000:00:02.0, NVIDIA 0000:01:00.0) diubah ke `/dev/dri/cardN`, jadi aman walau nomor kartu bertukar. Lokasinya di `~/.config/hypr/hyprland.lua` (sejak Hyprland 0.57; `.conf` tidak dimuat lagi).
- **Jika masih ada masalah:** 
  1. Komentari blok `AQ_DRM_DEVICES` di `hyprland.lua` (beri `--`) agar Aquamarine otomatis mendeteksi display aktif.
  2. Buka TTY (`Ctrl+Alt+F3`) dan jalankan `Hyprland` langsung untuk membaca log.
