#!/bin/bash

# ========================================
# LOKAL AI (DOCKER VERSION)
# ========================================

echo "=== Model Controller ==="
echo "1. Jalankan Llama 3.2 (Ringan & Cepat)"
echo "2. Jalankan Gemma 2 9B (Cerdas & Detail)"
echo "3. Matikan/Stop Model (Hemat VRAM)"
echo "4. Cek Status GPU (nvidia-smi)"
read -p "Pilih opsi [1-4]: " pil

case $pil in
    1)
        echo "Memulai Llama 3.2..."
        sudo docker exec -it ollama ollama run llama3.2
        ;;
    2)
        echo "Memulai Gemma 2 9B..."
        sudo docker exec -it ollama ollama run gemma2:9b
        ;;
    3)
        echo "Menghentikan semua proses model..."
        # Mengirim sinyal stop ke ollama di dalam docker
        sudo docker exec -it ollama pkill ollama
        echo "Model telah dihentikan. VRAM seharusnya sudah kosong."
        ;;
    4)
        nvidia-smi
        ;;
    *)
        echo "Pilihan tidak valid."
        ;;
esac
