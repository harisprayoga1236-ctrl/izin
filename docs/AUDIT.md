# Audit Installer — temuan & perubahan

Dokumen ini mencatat hasil pemeriksaan `install` (installer obfuscated dari
`arivpnstores/v4`) dan perbaikan yang dilakukan di repo ini.

## Cara decode

File `install` terdiri dari dua bagian:

1. **Blok patch** di 16 baris pertama (function `wget`, gerbang lisensi
   `__izin_gate`, dan variabel baru).
2. **Bagian obfuscated**: ratusan variabel acak (`ABBz='DROP'`, …) lalu satu
   baris `eval` yang mengekspansi semuanya menjadi script utuh.

Untuk membaca isi aslinya, ekspansi variabel pada baris `eval` secara rekursif
menggunakan nilai variabel di sekitarnya, lalu ganti `$z` dengan newline.

## Temuan

| # | Temuan | Dampak |
|---|---|---|
| 1 | **Reinstall OS otomatis** — jika OS bukan Ubuntu 20.04, menjalankan `bin456789/reinstall` lalu `reboot` | Seluruh data VPS hilang |
| 2 | **Token bot Telegram tertanam** — owner token `8238209608` + chat ID | Installer mengirim notifikasi (IP, domain) ke bot pembuat script. Token ini publik karena ada di repo. |
| 3 | File eksternal dijalankan sebagai root — `Fls/limit-ip`, `Fls/nameserver`, `Cfg/*`, `Fls/sshd`, `Fls/password` | Tidak ada verifikasi checksum; isi dapat berubah kapan saja |
| 4 | `fix-izin.sh` upstream diambil dari `arivpnstores/v4` | Lisensi repo ini tidak berlaku bila patch tidak dipasang |
| 5 | Password email tertanam (`msmtp`) | Kredensial SMTP bisa bocor |

## Perbaikan di repo ini

- [x] **Patch `fix-izin.sh`** — fungsi `wget` lokal mengarahkan unduhan
      `arivpnstores/v4/main/fix-izin.sh` ke repo ini, sehingga daftar IP di
      `ip` benar-benar dipakai.
- [x] **Gerbang lisensi** (`__izin_gate`) dijalankan sebelum apa pun, dan
      menghentikan instalasi bila lisensi ditolak.
- [x] **Token bot di-redact** — fragmen token dan chat ID pada tabel variabel
      diganti `REDACTED`. Script tetap berjalan, tetapi tidak lagi mengirim
      notifikasi ke bot tersebut.
- [ ] **Reinstall OS otomatis** — belum diubah. Jalankan hanya pada VPS yang
      isinya boleh hilang, atau di Ubuntu 20.04 agar cabang reinstall dilewati.

## Pemeriksaan setelah clone

```bash
bash -n install          # cek sintaks
bash -n fix-izin.sh
bash fix-izin.sh verify  # uji lisensi untuk IP ini
```

## Peringatan

- Installer ini mengubah banyak hal di sistem: SSH, Dropbear, OpenVPN, Xray,
  HAProxy, Nginx, iptables, cron, fail2ban.
- Jangan jalankan di server produksi tanpa backup.
- Ganti password root dan semua kredensial setelah instalasi.
