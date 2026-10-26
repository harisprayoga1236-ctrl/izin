# Instalasi dari Nol

Urutan lengkap: siapkan VPS → daftarkan IP → jalankan installer.
**Tidak ada langkah secret.**

---

## TL;DR

```bash
# 1) daftarkan IP (dari mesin admin)
izin <IP_VPS> --upload

# 2) tunggu ±1 menit, lalu di VPS
apt update -y && apt install --reinstall wget curl -y \
  && apt install screen python3-pip -y \
  && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/setup.sh -O /tmp/setup.sh \
  && chmod +x /tmp/setup.sh \
  && screen -S setup-session bash -c "/tmp/setup.sh"
```

---

## Tahap 0 — Prasyarat

| Kebutuhan | Keterangan |
|---|---|
| VPS | **Ubuntu 20.04**, x86_64, akses root, **KVM** |
| IP publik | Langsung pada VPS (bukan di belakang NAT) |
| Data | VPS **kosong** — installer me-reinstall OS bila versinya berbeda |

> ⚠️ Pada OS selain Ubuntu 20.04, installer menjalankan `reinstall.sh` lalu
> `reboot`. **Seluruh disk terhapus.** Backup dulu bila ada data.

---

## Tahap 1 — Cari IP publik VPS

Jalankan **di dalam VPS**, bukan di mesin admin:

```bash
curl -4 ifconfig.me
```

Contoh hasil: `103.190.0.55`. Angka inilah yang harus cocok dengan daftar lisensi.
Bila VPS di belakang NAT/proxy, hasilnya bisa berbeda dan lisensi akan ditolak.

---

## Tahap 2 — Daftarkan IP

Di mesin admin (`/root/izin-lisensi`):

```bash
izin 103.190.0.55 --upload
```

Atau dengan user dan tanggal sendiri:

```bash
izin 103.190.0.55 budi 2027-06-30 --upload
```

Nilai bawaan: user `haris`, expired **+1 tahun**.

Periksa:

```bash
izin --daftar
```

```
  103.190.0.55     budi         2027-06-30   248 hari lagi
```

---

## Tahap 3 — Tunggu cache GitHub

Cache `raw.githubusercontent.com` bisa tertunda ±3 menit. Pastikan sudah tampil:

```bash
curl -s "https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip?nocache=$(date +%s)"
```

Kalau instalasi dijalankan sebelum cache berubah, VPS akan ditolak.

---

## Tahap 4 — Jalankan instalasi

```bash
apt update -y && apt install --reinstall wget curl -y \
  && apt install screen python3-pip -y \
  && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/setup.sh -O /tmp/setup.sh \
  && chmod +x /tmp/setup.sh \
  && screen -S setup-session bash -c "/tmp/setup.sh"
```

Yang muncul lebih dulu:

```
━━━━━━━━━━━━━━━━━━━━━━
 IZIN SCRIPT AKTIF ✅
 USER   : budi
 EXP    : 2027-06-30
 IP     : 103.190.0.55
 CITY   : ...
 ISP    : ...
 MODE   : IP Khusus
━━━━━━━━━━━━━━━━━━━━━━
```

Lalu instalasi berjalan 20–40 menit.

### Memantau

```bash
Ctrl+A lalu D     # keluar, proses tetap jalan
screen -r ari     # kembali
screen -ls        # daftar sesi
```

---

## Tahap 5 — Setelah selesai

```
==========================
      INSTALL SUCCES
==========================
```

```bash
exec bash
menu
```

Cek layanan:

```bash
systemctl is-active xray nginx haproxy dropbear udp-custom
```

---

## Tahap 6 — Pengamanan

- Ganti password root: `passwd`
- Periksa service tidak dikenal: `systemctl list-units --type=service --state=running`
- Periksa cron: `ls -la /etc/cron.d/`
- **Jangan simpan data pribadi** di server ini — installer mengirim notifikasi
  (IP, domain, masa aktif) ke Telegram pembuat script, dan password email
  tertanam di dalamnya.

---

## Kalau gagal

| Pesan | Penyebab | Solusi |
|---|---|---|
| `❌ GAGAL MENGUNDUH FILE LISENSI` | VPS tak bisa akses GitHub | `curl -I https://raw.githubusercontent.com` |
| `❌ IP VPS BELUM TERDAFTAR` | IP tidak ada di daftar, atau cache belum berubah | Cek `curl -4 ifconfig.me`, lalu Tahap 2–3 |
| `❌ LICENSE SUDAH EXPIRED` | Tanggal lewat / jam VPS salah | Perpanjang: `izin +IP 1y --upload` |
| `❌ FORMAT TANGGAL TIDAK VALID` | Tanggal rusak di `ip` | Perbaiki barisnya |
| `❌ TIDAK ADA curl/wget` | VPS minimal | `apt install -y curl` |
| `OpenVZ is not supported` | Virtualisasi tidak didukung | Pakai KVM |

### Cek mandiri tanpa install

```bash
curl -4 ifconfig.me
curl -s "https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip?nocache=$(date +%s)"
```

Bandingkan. Kalau IP tidak ada di daftar, itu penyebabnya.

---

## Daftar periksa

- [ ] VPS kosong / sudah dibackup
- [ ] OS Ubuntu 20.04, KVM
- [ ] IP publik sudah dicatat dari dalam VPS
- [ ] `izin <IP> --upload` sudah dijalankan
- [ ] Baris IP sudah terlihat di raw GitHub
- [ ] Installer dijalankan di `screen`
