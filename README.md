# izin — Sistem Lisensi Script Arivpnstores v4

Lisensi berbasis **IP + HMAC-SHA256** untuk mengizinkan instalasi script VPN
pada VPS tertentu.

- `fix-izin.sh` — script verifikasi lisensi
- `ip` — daftar lisensi (IP, user, tanggal expired, signature)

> Script ini dipanggil oleh installer sebelum instalasi dimulai. Jika lisensi
> ditolak, instalasi berhenti.

---

## Format file `ip`

```
IP  USER  EXPIRED  SIGNATURE
```

| Kolom | Isi |
|---|---|
| 1 | Alamat IP VPS, atau `ALL` untuk semua IP |
| 2 | Username pemilik lisensi |
| 3 | Tanggal expired `YYYY-MM-DD` |
| 4 | HMAC-SHA256 hex dari `IP\|USER\|EXPIRED` |

`SIGNATURE` tidak bisa dihitung tanpa secret. Tanpa secret, lisensi tidak bisa
dipalsukan meski file ini publik.

Baris berawalan `#` diabaikan.

Contoh:

```
103.10.20.30     rafi         2027-01-15   ed6ee1929f751f8e42e5257553c98e46...
66.33.22.247     haris        2027-03-01   5a6663f5e0c6f46d94fbfac36946f6...
ALL              haris        2027-06-30   006c10666fbba708aaf9c8d3ef862d...
```

### Tentang `ALL`

Baris `ALL` berlaku untuk **semua IP** yang tidak punya baris khusus.
Aktifkan hanya selama masa uji atau untuk akses terbuka terkontrol.
IP spesifik selalu diutamakan di atas `ALL`.

---

## Membuat lisensi baru

Butuh `openssl` dan secret yang sama dengan yang ada di VPS.

```bash
SIG=$(printf '%s' "103.10.20.30|rafi|2027-01-15" \
      | openssl dgst -sha256 -hmac "$SECRET" -r | cut -d' ' -f1)
printf '%-16s %-12s %-12s %s\n' "103.10.20.30" "rafi" "2027-01-15" "$SIG"
```

Hasilnya tempel sebagai satu baris baru di file `ip`, lalu commit.

---

## Verifikasi di VPS

Secret dibaca dari salah satu sumber, berurutan:

1. variabel environment `IZIN_SECRET`
2. file `/etc/izin-secret`

```bash
export IZIN_SECRET='secret-anda'
bash fix-izin.sh verify
```

Hasil yang mungkin:

```
✅ Lisensi valid untuk rafi sampai 2027-01-15
❌ IP VPS BELUM TERDAFTAR: 1.2.3.4
❌ SIGNATURE TIDAK VALID untuk baris lisensi ini
❌ SECRET LISENSI TIDAK DIKONFIGURASI DI SERVER INI
```

---

## Instalasi lengkap

### 0. Prasyarat

| Kebutuhan | Keterangan |
|---|---|
| VPS | **Ubuntu 20.04**, x86_64, akses root |
| IP publik | Langsung pada VPS (bukan di belakang NAT) |
| Domain | Opsional, untuk SSL |

> ⚠️ **Jangan jalankan installer pada VPS yang berisi data.** Installer
> memeriksa versi OS dan akan me-reinstall sistem + reboot bila bukan
> Ubuntu 20.04. Seluruh disk terhapus.

### 1. Daftarkan IP VPS

Dari dalam VPS:

```bash
curl -4 ifconfig.me
```

Buat signature dengan IP tersebut, lalu tambahkan satu baris ke `ip` dan
commit. Pastikan baris itu terlihat di:

```bash
curl -s "https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip?x=$(date +%s)"
```

### 2. Pasang secret di VPS

```bash
echo 'secret-anda' > /etc/izin-secret
chmod 600 /etc/izin-secret
```

Periksa:

```bash
ls -l /etc/izin-secret     # harus -rw------- root root
```

Tanpa langkah ini instalasi akan berhenti dengan
`❌ SECRET LISENSI TIDAK DIKONFIGURASI DI SERVER INI`.

### 3. Jalankan installer

Installer yang sudah dipatch akan:

1. mengunduh `fix-izin.sh` dari repo ini,
2. menjalankannya sebagai gerbang,
3. berhenti bila lisensi gagal.

```bash
chmod +x /tmp/install
screen -S ari /tmp/install
```

Yang diharapkan muncul:

```
━━━━━━━━━━━━━━━━━━━━━━
 IZIN SCRIPT AKTIF ✅
 USER   : haris
 EXP    : 2027-01-15
 IP     : 103.10.20.30
━━━━━━━━━━━━━━━━━━━━━━
```

### 4. Pantau instalasi

```bash
Ctrl+A lalu D     # keluar dari screen, proses tetap jalan
screen -r ari     # kembali melihat
screen -ls        # daftar sesi
```

Durasi 20–40 menit.

### 5. Setelah selesai

```bash
exec bash
menu
```

Cek layanan:

```bash
systemctl status xray nginx haproxy dropbear udp-custom
```

---

## Mengatasi masalah

| Pesan | Penyebab | Solusi |
|---|---|---|
| `GAGAL MENGUNDUH FILE LISENSI` | Tidak bisa akses GitHub | Uji `curl -I https://raw.githubusercontent.com` |
| `IP VPS BELUM TERDAFTAR` | IP tidak ada di `ip` | Tambahkan baris IP tersebut |
| `SIGNATURE LISENSI TIDAK VALID` | Secret VPS ≠ secret penandatangan | Samakan `/etc/izin-secret` |
| `SECRET LISENSI TIDAK DIKONFIGURASI` | `/etc/izin-secret` belum ada | Langkah 2 |
| `LICENSE SUDAH EXPIRED` | Tanggal terlewat | Perpanjang di `ip` |
| `TIDAK ADA curl/wget` | VPS sangat minimal | `apt install -y curl` |
| `OpenVZ is not supported` | Virtualisasi tidak didukung | Gunakan KVM |

---

## Catatan keamanan

- **Secret tidak boleh masuk repo ini.** Secret hanya ada di `/etc/izin-secret`
  pada tiap VPS.
- Lisensi diverifikasi **saat instalasi saja**; tidak ada pengecekan berkala.
- File `ip` bersifat publik. Isi IP VPS terlihat siapa pun — ini konsekuensi
  desain, bukan kebocoran secret.
- Menghapus `/etc/izin-secret` setelah instalasi tidak mematikan layanan yang
  sudah berjalan.
