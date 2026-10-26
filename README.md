# izin — Lisensi IP untuk Installer Script

Repo ini berisi dua hal:

| File | Fungsi |
|---|---|
| `ip` | Daftar IP yang diizinkan menginstal |
| `fix-izin.sh` | Script yang mencocokkan IP VPS dengan daftar |
| `install` | Installer script (memanggil `fix-izin.sh` lebih dulu) |

Cara kerjanya sederhana: **installer mengambil IP publik VPS, mencocokkannya
dengan daftar di file `ip`, lalu berhenti bila tidak cocok.**

Tidak ada secret, token, atau signature untuk sistem lisensinya. Pemilik repo
yang menentukan daftarnya.

> **Catatan penting:** installer asli (`arivpnstores/v4`) masih memuat token
> bot Telegram pembuatnya dan mengirim notifikasi ke sana saat dipasang.
> Di repo ini nilai token tersebut sudah di-redact, tetapi **notifikasi
> Telegram memang masih terkirim** karena seluruh mekanisme itu tertanam di
> script asli. Lihat `docs/AUDIT.md`.

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
apt update -y && apt install screen curl wget python3-pip -y \
  && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/install -O /tmp/install \
  && chmod +x /tmp/install \
  && screen -S ari /tmp/install
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

Pantau dengan `screen -r ari`. Keluar tanpa mematikan proses: `Ctrl+A` lalu `D`.

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
