# Panduan Sistem Lisensi

Sistem lisensi kini berjalan dalam **mode IP**: cukup mencocokkan alamat IP
publik VPS dengan daftar di file `ip`.

**Tidak ada secret, tidak ada signature, tidak ada token di VPS.**
Panduan ini menggantikan versi HMAC sebelumnya.

---

## Cara kerja

```
VPS                      GitHub                        Installer
 │                          │                              │
 │  1. curl ifconfig.me ────┼─────────────────────────────▶│ ambil IP publik
 │                          │                              │
 │  2. GET .../izin/main/ip─┼─────────────────────────────▶│ ambil daftar
 │                          │                              │
 │  3. cocokkan IP ─────────┼─────────────────────────────▶│ cocok? lanjut
 │                          │                              │ tidak? stop
```

Pencocokan dilakukan oleh `fix-izin.sh`, yang dipanggil oleh `install`
sebelum instalasi dimulai.

---

## File di folder ini

| File | Fungsi |
|---|---|
| `ip` | Daftar lisensi (IP, user, tanggal) — yang diunggah ke GitHub |
| `fix-izin.sh` | Pemeriksa IP |
| `install` | Installer dengan gerbang lisensi |
| `izin` | Perintah tambah/perpanjang lisensi |
| `upload.sh` | Unggah ke GitHub (`./upload.sh --readme` untuk sertakan README) |
| `patch_installer.py` | Membuat ulang `install` bila installer Arivpn diperbarui |
| `README-repo.md` | Isi README di GitHub |
| `CHECKLIST-103.190.0.22.md` | Checklist untuk VPS tersebut |

---

## Format file `ip`

```
IP    USER    EXPIRED
```

```
103.190.0.22     haris    2027-12-31
```

- Baris berawalan `#` diabaikan.
- IP spesifik diutamakan di atas `ALL`.
- Tanggal lewat → instalasi ditolak.
- Kolom ke-4 dan seterusnya diabaikan.

---

## Menambah lisensi

```bash
izin 103.190.0.55                 # user haris, expired +1 tahun
izin 103.190.0.55 budi 30d        # 30 hari
izin 103.190.0.55 budi 2027-06-30 # tanggal persis
izin 103.190.0.55 --upload        # sekalian unggah
```

## Memperpanjang

```bash
izin +103.190.0.22 1y      # dari tanggal expired lama (jika masih aktif)
izin +103.190.0.22 30d
```

Bila lisensi sudah kedaluwarsa, perpanjangan dihitung dari **hari ini**.

## Mengubah tanggal saja

```bash
izin =103.190.0.22 2028-06-30
```

## Melihat daftar

```bash
izin --daftar
```

## Mencabut

Hapus barisnya dari `ip`, lalu `./upload.sh`.

---

## Instalasi di VPS

```bash
apt update -y && apt install screen curl wget python3-pip -y \
  && wget -q https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/install -O /tmp/install \
  && chmod +x /tmp/install \
  && screen -S ari /tmp/install
```

Tidak ada langkah secret. Tidak ada `export`.

Hasil yang benar:

```
━━━━━━━━━━━━━━━━━━━━━━
 IZIN SCRIPT AKTIF ✅
 USER   : haris
 EXP    : 2027-12-31
 IP     : 103.190.0.22
 MODE   : IP Khusus
━━━━━━━━━━━━━━━━━━━━━━
```

---

## Keamanan — baca ini

Repo `izin` **publik**. Konsekuensinya:

- Daftar IP Anda terlihat siapa pun.
- **Siapa pun yang bisa menulis ke repo bisa menambah IP sendiri.**
  Karena itu, amankan akun GitHub Anda (2FA, token yang tidak dibagikan).
- Tidak ada verifikasi kriptografis. Sistem ini memfilter, bukan mengunci.

Kalau perlu lebih ketat, opsi yang tersedia: repo privat + token di VPS, atau
menyajikan `ip` dari host privat. Keduanya belum diterapkan.
