# Cara Upload ke GitHub

Yang di-upload ke repo `harisprayoga1236-ctrl/izin`:

| File lokal | Nama di GitHub |
|---|---|
| `fix-izin.sh` | `fix-izin.sh` |
| `ip` | `ip` |
| `README-repo.md` | `README.md` (hanya bila pakai `--readme`) |
| `install` | `install` (diunggah terpisah, lihat bagian bawah) |

**Tidak ada secret.** Sistem mode IP tidak memakainya.

---

## Cara cepat

```bash
cd /root/izin-lisensi
./upload.sh              # fix-izin.sh + ip
./upload.sh --readme     # sekalian README
```

Contoh hasil:

```
→ Mengunggah fix-izin.sh ...
  ✔ fix-izin.sh | 019fa042
→ Mengunggah ip ...
  ✔ ip | 22fa3874
```

---

## Token GitHub

Diperlukan sekali untuk menyiapkan `upload.sh`.

### Membuat token

1. Buka https://github.com/settings/tokens?type=beta
2. **Generate new token**
3. Isi:
   - Token name: `izin-upload`
   - Resource owner: `harisprayoga1236-ctrl`
   - Repository access: **Only select repositories** → `izin`
4. **Permissions** → **Repository permissions** → **Contents** → **Read and write**
5. **Generate token**, salin nilainya (`github_pat_...`)

### Menyimpan token

```
! umask 077 && printf '%s' 'TOKEN_DISINI' > /root/.gh_token
```

Mode file harus `600`. Jangan tempel token ke chat atau ke file yang di-commit.

### Setelah selesai

Hapus token di halaman yang sama. Kalau nanti perlu upload lagi, buat baru.

---

## Kalau tidak mau pakai token

Edit langsung di browser:

1. https://github.com/harisprayoga1236-ctrl/izin/blob/main/ip
2. Ikon pensil → tambah baris → **Commit changes**

---

## Upload `install`

`upload.sh` tidak menyertakan `install` karena ukurannya besar (70 KB) dan
jarang berubah. Bila perlu memperbaruinya:

```bash
python3 -I - <<'PY'
import base64, json, urllib.request
token = open('/root/.gh_token').read().strip()
repo = "harisprayoga1236-ctrl/izin"
api = f"https://api.github.com/repos/{repo}/contents"
def call(url, method="GET", payload=None):
    req = urllib.request.Request(url, method=method,
        data=json.dumps(payload).encode() if payload else None,
        headers={"Authorization": f"Bearer {token}",
                 "Accept": "application/vnd.github+json",
                 "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=60))
body = {"message": "install: perbarui installer",
        "content": base64.b64encode(open('install','rb').read()).decode(),
        "branch": "main"}
try:
    body["sha"] = call(f"{api}/install")["sha"]
except Exception:
    pass
r = call(f"{api}/install", "PUT", body)
print("✔ install", r["commit"]["sha"][:8])
PY
```

---

## Cache GitHub

Setelah commit, `raw.githubusercontent.com` bisa tertunda **beberapa puluh detik
hingga ±3 menit**. Ini normal.

Cek:

```bash
curl -s "https://raw.githubusercontent.com/harisprayoga1236-ctrl/izin/main/ip?nocache=$(date +%s)"
```

Kalau ingin memastikan tanpa menunggu cache, pakai API (selalu versi terbaru):

```bash
curl -s -H "Authorization: Bearer $(cat /root/.gh_token)" \
  https://api.github.com/repos/harisprayoga1236-ctrl/izin/contents/ip \
  | python3 -c "import sys,json,base64;print(base64.b64decode(json.load(sys.stdin)['content']).decode())"
```

---

## Memulihkan versi lama

Semua perubahan tersimpan sebagai commit. Buka
https://github.com/harisprayoga1236-ctrl/izin/commits/main → pilih commit lama →
lihat file → salin isinya.