# izin — Lisensi IP untuk Installer Script

Repo ini berisi dua hal:

| File | Fungsi |
|---|---|
| `ip` | Daftar IP yang diizinkan menginstal |
| `fix-izin.sh` | Script yang mencocokkan IP VPS dengan daftar |
| `install` | Installer script (memanggil `fix-izin.sh` lebih dulu) |
| `setup.sh` | Pemasang installer: unduh `install`, cek sintaks, lalu jalankan di `screen` |
| `Vpn/xray.zip` | Salinan `install` dengan nama warisan arivpnstores. Disamakan lewat `./sync-vpn.sh` |

Cara kerjanya sederhana: **installer mengambil IP publik VPS, mencocokkannya
dengan daftar di file `ip`, lalu berhenti bila tidak cocok.**

Tidak ada secret, token, atau signature untuk sistem lisensinya. Pemilik repo
yang menentukan daftarnya.

> **Catatan penting:** installer asli (`arivpnstores/v4`) memuat token bot
> Telegram pembuatnya dan mengirim notifikasi ke sana. Di repo ini token
> tersebut sudah di-redact, pengirim notifikasinya sudah dimatikan, dan
> reinstall OS otomatis sudah dinonaktifkan. Lihat `docs/AUDIT.md`.

---

## Cara Instal (ringkas)

Satu langkah utama: **jalankan instalasi.** IP VPS dicek otomatis oleh
`fix-izin.sh`, jadi Anda tidak perlu mencarinya sendiri.

### Instalasi

```bash
apt update -y && apt install --reinstall wget curl -y \
  && apt install screen python3-pip -y \
  && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/Vpn/xray.zip -O /tmp/install \
  && chmod +x /tmp/install \
  && screen -S setup-session bash -c "/tmp/install"
```

Atau lewat `setup.sh` (mengunduh `/main/install`, cek sintaks, lalu jalankan):

```bash
apt update -y && apt install --reinstall wget curl -y \
  && apt install screen python3-pip -y \
  && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/setup.sh -O /tmp/setup.sh \
  && chmod +x /tmp/setup.sh \
  && screen -S setup-session bash -c "/tmp/setup.sh"
```

Keduanya memberi installer yang sama persis (`Vpn/xray.zip` adalah salinan `install`).

Instalasi akan berhenti sendiri di awal kalau IP VPS belum terdaftar atau
lisensinya sudah expired.

### VPS yang sudah terdaftar

| IP | User | Berlaku sampai |
|---|---|---|
| `103.190.0.22` | haris | 2027-12-31 |

Di VPS ini lisensi sudah aktif — langsung jalankan perintah instalasi di atas.
Cek cepat sebelum mulai:

```bash
curl -s "https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/fix-izin.sh?nocache=$(date +%s)" -o /tmp/cek.sh
bash /tmp/cek.sh verify
```

Harus muncul:

```
✅ Lisensi valid untuk haris sampai 2027-12-31 (IP: 103.190.0.22)
```

### Kalau IP belum terdaftar

Installer menampilkan IP-nya, misalnya:

```
❌ IP VPS BELUM TERDAFTAR
    IP: 103.190.0.55
```

Tambahkan baris itu ke file `ip` (lihat [bagian 2](#2-menambah-ip-lewat-github-langsung-di-browser)), lalu ulangi perintah di atas:

```
103.190.0.55     haris        2027-12-31
```

> Opsional: `curl -4 -s ifconfig.me` hanya untuk memastikan IP yang dilihat VPS
> sama dengan yang Anda daftarkan. Tidak wajib.

### Selama dan sesudah instalasi

| Keperluan | Perintah |
|---|---|
| Keluar dari screen (install tetap jalan) | `Ctrl+A` lalu `D` |
| Masuk kembali | `screen -r setup-session` |
| Lihat daftar screen | `screen -ls` |

Yang muncul lebih dulu saat instalasi:

```
━━━━━━━━━━━━━━━━━━━━━━
 IZIN SCRIPT AKTIF ✅
 USER   : haris
 EXP    : 2027-12-31
 IP     : 103.190.0.22
 MODE   : IP Khusus
━━━━━━━━━━━━━━━━━━━━━━
```

### Syarat

- **Ubuntu 20.04** — reinstall otomatis sudah dimatikan, tapi di versi lain
  sebagian paket bisa gagal.
- Root / sudo.
- IP publik sudah terdaftar dan belum expired.

### Catatan versi installer

Repo ini memakai installer `arivpnstores/v4` dengan beberapa perbaikan:

| Perbaikan | Keterangan |
|---|---|
| Reinstall OS otomatis | Dimatikan — VPS tidak lagi diformat |
| Notifikasi Telegram | Dimatikan — tidak ada data keluar |
| Token bot Telegram | Di-redact |
| `Cfg/dro.conf` | Diperbaiki menjadi `Cfg/dropbear.conf` |
| Lisensi | Dicek lewat `fix-izin.sh` milik repo ini |

Installer masih mengunduh file konfigurasi dari
`arivpnstores/v4` (Xray, HAProxy, Nginx, SSH, OpenVPN, dll). Kalau repo itu
hilang, instalasi tidak bisa berjalan.

---

## 1. Format file `ip`

Satu baris per IP, tiga kolom dipisah spasi:

```
IP    USER    EXPIRED
```

```
103.190.0.22     haris    2027-12-31
66.33.22.247     haris    2027-03-01
```

| Kolom | Isi |
|---|---|
| 1 | Alamat IP publik VPS, atau `ALL` |
| 2 | Nama pengguna lisensi (bebas, hanya label) |
| 3 | Tanggal berakhir `YYYY-MM-DD` |

Aturan:

- Baris berawalan `#` diabaikan.
- Baris kosong diabaikan.
- `IP` spesifik **selalu diutamakan** di atas `ALL`.
- `ALL` berlaku untuk semua IP yang tidak punya baris sendiri.
  **Jangan diaktifkan** kecuali memang ingin semua IP bisa install.
- Bila tanggal sudah lewat, instalasi ditolak meskipun IP terdaftar.
- Kolom ke-4 dan seterusnya diabaikan. Jadi baris lama dengan signature
  (format 4 kolom) **tetap diterima** — kolom tanda tangannya dilewati saja.

---

## 2. Menambah IP lewat GitHub (langsung di browser)

Dipakai bila Anda tidak sedang memakai terminal.

### Langkah 1 — Cari IP VPS

Masuk ke VPS, jalankan:

```bash
curl -4 ifconfig.me
```

Catat hasilnya, misalnya `103.190.0.55`.

> Pastikan yang keluar adalah IP publik VPS itu sendiri. Pada VPS di belakang
> NAT, hasilnya bisa berbeda dan lisensi tidak akan cocok.

### Langkah 2 — Buka file `ip` di GitHub

Buka:

```
https://github.com/harisprayoga1236-ctrl/izin/blob/main/ip
```

Klik ikon **pensil** (Edit this file) di kanan atas.

### Langkah 3 — Tambah satu baris

Tambahkan di akhir daftar:

```
103.190.0.55     haris    2027-12-31
```

Pisahkan kolom dengan spasi. Tanggal **harus** `YYYY-MM-DD`.

Contoh hasil akhir file:

```
# File lisensi (mode IP — tanpa signature)
# Format: IP  USER  EXPIRED
# Baris berawalan # diabaikan.

103.10.20.30     rafi     2027-01-15
66.33.22.247     haris    2027-03-01
103.190.0.22     haris    2027-12-31
103.190.0.55     haris    2027-12-31
```

### Langkah 4 — Commit

Klik **Commit changes**, lalu **Commit changes** sekali lagi pada dialog.

### Langkah 5 — Tunggu cache GitHub

Perubahan di `raw.githubusercontent.com` bisa tertunda **beberapa puluh detik
hingga ±3 menit** setelah commit. Ini normal.

Cek apakah sudah berlaku:

```bash
curl -s "https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip?nocache=$(date +%s)"
```

Baris baru Anda harus sudah muncul. Kalau belum, tunggu lalu ulangi.

### Langkah 6 — Install di VPS

```bash
apt update -y && apt install --reinstall wget curl -y \
  && apt install screen python3-pip -y \
  && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/setup.sh -O /tmp/setup.sh \
  && chmod +x /tmp/setup.sh \
  && screen -S setup-session bash -c "/tmp/setup.sh"
```

Yang harus muncul lebih dulu:

```
━━━━━━━━━━━━━━━━━━━━━━
 IZIN SCRIPT AKTIF ✅
 USER   : haris
 EXP    : 2027-12-31
 IP     : 103.190.0.55
 MODE   : IP Khusus
━━━━━━━━━━━━━━━━━━━━━━
```

Baru setelah blok itu, instalasi berjalan (20–40 menit).

Pantau dengan `screen -r setup-session`. Keluar tanpa mematikan proses: `Ctrl+A` lalu `D`.

---

## 3. Mengubah tanggal / memperpanjang

Sama caranya: edit baris IP tersebut di file `ip`, ubah kolom ketiga, commit.

```
103.190.0.55     haris    2028-12-31
```

Lisensi hanya dibaca **saat instalasi**. Setelah install selesai, mengubah
tanggal tidak mematikan layanan yang sudah berjalan.

---

## 4. Mencabut izin

Hapus baris IP tersebut dari file `ip`, lalu commit.

VPS itu tidak bisa menginstal lagi. Layanan yang sudah terpasang tetap berjalan.

---

## 5. Alternatif: lewat terminal

Bila tersedia, cara ini lebih cepat dan ada validasi otomatis:

```bash
izin 103.190.0.55 haris 2027-12-31 --upload
```

```bash
izin --daftar          # lihat semua lisensi + sisa hari
izin +103.190.0.22 1y  # perpanjang 1 tahun dari tanggal lama
```

Keduanya mengubah file yang sama.

---

## 6. Mengatasi masalah

| Pesan di VPS | Penyebab | Solusi |
|---|---|---|
| `❌ IP VPS BELUM TERDAFTAR` | IP tidak ada di `ip`, atau cache GitHub belum berubah | Cek `curl -4 ifconfig.me` di VPS, lalu pastikan barisnya ada di raw GitHub |
| `❌ LICENSE SUDAH EXPIRED` | Tanggal kolom 3 sudah lewat, atau jam VPS salah | Ubah tanggal di `ip`; cek `date` di VPS |
| `❌ FORMAT LICENSE TIDAK VALID` | Kolom terlalu sedikit (tanggal atau user kosong) | Minimal `IP USER TANGGAL` |
| `❌ FORMAT TANGGAL TIDAK VALID` | Tanggal bukan `YYYY-MM-DD` atau tidak ada di kalender | Contoh benar: `2027-12-31` |
| `❌ GAGAL MENGAMBIL FILE LISENSI` | VPS tidak bisa akses GitHub | `curl -I https://raw.githubusercontent.com` |
| `❌ TIDAK ADA curl/wget` | VPS sangat minimal | `apt install -y curl` |
| `MODE : ALL` padahal tidak diinginkan | Baris `ALL` aktif | Beri tanda `#` di awal baris `ALL` |

Cek cepat dari VPS tanpa install:

```bash
curl -s "https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip?nocache=$(date +%s)"
curl -4 ifconfig.me
```

Bandingkan dua hasil itu. Kalau IP tidak muncul di daftar, itulah penyebabnya.

---

## 7. Peringatan

- **Repo ini publik.** Daftar IP dan isi `install` bisa dilihat siapa pun.
- Karena tidak ada signature, **siapa pun yang bisa menulis ke repo ini bisa
  menambah IP sendiri**. Jaga keamanan akun GitHub Anda (2FA).
- Installer memeriksa versi OS. Pada OS selain Ubuntu 20.04 ia akan
  me-reinstall sistem — **data di VPS terhapus**. Pakai VPS kosong.
- Layanan yang sudah terpasang tidak terpengaruh perubahan `ip` berikutnya;
  lisensi hanya diperiksa saat instalasi.
