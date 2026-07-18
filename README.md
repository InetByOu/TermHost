# TermHost

> Termux Hosting Manager

Tool untuk mengelola web hosting langsung dari Termux dengan mudah dan cepat.

## ✨ Fitur

- Setup hosting website di Termux dengan cepat
- Mendukung PHP, Node.js, Python, dan static site
- Manajemen port & tunneling otomatis
- Interface CLI yang sederhana
- Monitoring status server
- Mudah dijalankan di Android

## 📋 Persyaratan

- Termux (Android)
- Git
- Python 3 (opsional, tergantung fitur)
- Storage permission di Termux

## 🚀 Instalasi

```bash
# Update Termux
pkg update && pkg upgrade -y

# Clone repository
 git clone https://github.com/InetByOu/TermHost.git
cd TermHost

# Beri izin eksekusi
chmod +x *.sh

# Jalankan
./termhost.sh
```

## 📖 Penggunaan

```bash
# Mulai hosting
termhost start

# Cek status
termhost status

# Stop hosting
termhost stop

# Lihat bantuan
termhost help
```

## ⚙️ Konfigurasi

Edit file konfigurasi sesuai kebutuhan kamu di:

```bash
config/config.json
```

## 🤝 Kontribusi

Pull request sangat diterima! Silakan fork repo ini dan buat perubahan yang kamu inginkan.

## 📄 Lisensi

Lihat file [LICENSE](LICENSE) untuk detail lisensi.