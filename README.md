# TermHost

> Termux Web Hosting Manager

Tool interaktif untuk menjalankan web hosting (Nginx + PHP-FPM + MariaDB) langsung di Termux dengan dukungan Virtual Host dan akses publik.

## Instalasi (One Command)

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Setelah install, jalankan:
```bash
termhost
```

## Fitur Utama

- **Virtual Host** — Akses website via `http://namawebsite.localhost:8080`
- **Hosting dari SD Card** — Serve file langsung dari storage
- **Auto Start** — Bisa jalan otomatis saat Termux dibuka
- **Public Access** — Ngrok, Cloudflare Tunnel, localhost.run
- **Database Management** — Buat & kelola database MariaDB
- **Termux:Boot** — Auto start saat device boot (khusus root)
- **Auto Swap** — Buat swap otomatis jika RAM < 2GB (khusus root)
- **Error Handling** — Lebih aman dan user-friendly

## Port

- **Non-root**: Direkomendasikan menggunakan port **8080** (default)
- **Root**: Bisa menggunakan port custom (contoh: 80 atau port lain sesuai kebutuhan)

## Cara Penggunaan

1. Jalankan `termhost`
2. Pilih menu yang diinginkan
3. Buat website baru atau host dari SD Card
4. Start service
5. Akses via browser: `http://namawebsite.localhost:8080`

## Untuk User Root

- Menu **Termux:Boot** (auto start saat boot)
- Menu **Swap Management** (otomatis jika RAM rendah)
- Bisa pakai Magisk service untuk swap

## Update

```bash
cd ~/termhost && git pull
termhost
```

## Author
InetByOu