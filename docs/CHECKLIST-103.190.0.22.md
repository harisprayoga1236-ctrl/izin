# Checklist Instalasi — VPS 103.190.0.22

Lisensi: user `haris`, expired **2027-12-31**, mode **IP Khusus**.
Installer: `https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/install`

Sistem ini **mode IP** — tidak ada secret yang perlu dipasang.

---

## ⛔ Sebelum menyentuh apa pun

- [ ] **VPS kosong / sudah di-backup.** Installer memeriksa OS; kalau bukan
      Ubuntu 20.04 ia menjalankan `reinstall.sh` + `reboot` → **seluruh disk terhapus**.
- [ ] OS = **Ubuntu 20.04**, arsitektur **x86_64**
- [ ] Virtualisasi **KVM** (OpenVZ ditolak installer)
- [ ] IP publik VPS memang `103.190.0.22`

---

## Tahap A — Verifikasi IP

Login ke VPS:

```bash
ssh root@103.190.0.22
curl -4 ifconfig.me
```

- [ ] Hasilnya **tepat** `103.190.0.22`

Kalau berbeda (mis. `124.156.200.189`), **berhenti** — IP itu belum terdaftar.
Daftarkan dulu dari mesin admin: `izin <IP_BARU> --upload`.

---

## Tahap B — Uji lisensi sebelum instalasi

Tidak wajib, tapi menghindari menunggu lama lalu gagal.

```bash
curl -s "https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/fix-izin.sh?nocache=$(date +%s)" -o /tmp/cek.sh
bash /tmp/cek.sh verify
```

Yang harus muncul:

```
✅ Lisensi valid untuk haris sampai 2027-12-31 (IP: 103.190.0.22)
```

- [ ] Hasil `✅`

Kalau gagal:

| Pesan | Periksa |
|---|---|
| `IP VPS BELUM TERDAFTAR` | Hasil `curl -4 ifconfig.me` bukan `103.190.0.22` |
| `LICENSE SUDAH EXPIRED` | Tanggal di `ip` lewat, atau jam VPS salah → `timedatectl` |
| `GAGAL MENGAMBIL FILE LISENSI` | VPS tidak bisa akses GitHub |

---

## Tahap C — Jalankan instalasi

```bash
apt update -y && apt install --reinstall wget curl -y \
  && apt install screen python3-pip -y \
  && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/setup.sh -O /tmp/setup.sh \
  && chmod +x /tmp/setup.sh \
  && screen -S setup-session bash -c "/tmp/setup.sh"
```

- [ ] Blok lisensi muncul:
      ```
       IZIN SCRIPT AKTIF ✅
       USER   : haris
       EXP    : 2027-12-31
       IP     : 103.190.0.22
       MODE   : IP Khusus
      ```
      **`MODE` harus `IP Khusus`**, bukan `ALL`.
- [ ] Instalasi berlanjut (20–40 menit)

### Memantau

```bash
Ctrl+A lalu D     # keluar, proses tetap jalan
screen -r setup-session     # kembali
screen -ls        # daftar sesi
```

---

## Tahap D — Setelah selesai

Muncul:

```
==========================
      INSTALL SUCCES
==========================
```

- [ ] `exec bash` lalu `menu` berjalan
- [ ] Layanan hidup:
      ```bash
      systemctl is-active xray nginx haproxy dropbear udp-custom
      ```
- [ ] Port mendengarkan:
      ```bash
      ss -tlnp | grep -E ':(80|443|22)\b'
      ```

---

## Tahap E — Pengamanan

- [ ] Ganti password root: `passwd`
- [ ] Audit service: `systemctl list-units --type=service --state=running`
- [ ] Audit cron: `ls -la /etc/cron.d/`
- [ ] **Jangan** simpan data pribadi — installer mengirim notifikasi ke Telegram
      pembuat script dan memuat password email tertanam.

---

## Ringkasan satu layar

```bash
# A) pastikan IP
curl -4 ifconfig.me        # harus 103.190.0.22

# B) uji lisensi
curl -s "https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/fix-izin.sh?nocache=$(date +%s)" -o /tmp/cek.sh
bash /tmp/cek.sh verify

# C) install
apt update -y && apt install --reinstall wget curl -y \
  && apt install screen python3-pip -y \
  && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/setup.sh -O /tmp/setup.sh \
  && chmod +x /tmp/setup.sh \
  && screen -S setup-session bash -c "/tmp/setup.sh"

# D) setelah selesai
exec bash && menu
```
