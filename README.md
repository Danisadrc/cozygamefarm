<div align="center">

# 🌾 Cozy Valley
### *2D Cozy Farming & Village Life RPG*

![Godot Engine](https://img.shields.io/badge/Godot_Engine-4.3%2B-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white)
![Language](https://img.shields.io/badge/GDScript-Modular-355570?style=for-the-badge)
![Art Style](https://img.shields.io/badge/Pixel_Art-Sunnyside_World-7FB069?style=for-the-badge)
![Genre](https://img.shields.io/badge/Genre-Cozy_Farming_RPG-E6AA68?style=for-the-badge)

> *"Kelola kebun kecilmu di tepi desa, masak hidangan hangat di api unggun, jalin persahabatan dengan para warga, dan wujudkan kemakmuran Cozy Valley."*

</div>

---

## ✨ Fitur Utama

- 🌱 **Bertani 11 Jenis Tanaman**  
  Cangkul tanah, tabur bibit, siram setiap hari, dan panen 11 komoditas (*Beetroot, Cabbage, Carrot, Cauliflower, Kale, Parsnip, Potato, Pumpkin, Radish, Sunflower, Wheat*).
- 🎒 **Hotbar 5 Slot & Tas Ransel 15 Slot**  
  Manajemen inventaris ringkas dengan penyimpanan otomatis ke ransel serta fitur tukar slot, detail harga/stamina, dan konsumsi cepat.
- 🔥 **Memasak di Api Unggun (*Campfire Cooking*)**  
  Olah hasil kebun, ternak, dan pancingan menjadi 4 hidangan spesial (*Telur Dadar Desa, Ikan Bakar Kolam, Sup Sayur Hangat, Roti Gandum Manis*) dengan pemulihan stamina besar.
- 💝 **Sistem Pertemanan & Hadiah NPC**  
  Sapa warga desa dan berikan hadiah harian untuk meningkatkan tingkat keakraban (`0–5 Hati`) lengkap dengan bonus koin saat mencapai 3 Hati.
- ⚒️ **Upgrade Peralatan di Kios Pasar**  
  Tingkatkan Cangkul, Penyiram, Kapak, dan Beliung ke **Lv.2** untuk memangkas konsumsi stamina hingga 50% dan mempercepat penebangan/penambangan.
- 🪓 **Gathering, Memancing, & Beternak**  
  Tebang kayu, tambang batu, mainkan mini-game memancing di kolam desa, serta rawat ayam dan sapi untuk memanen telur dan susu segar setiap pagi.
- 📜 **5 Tahap Misi Utama & Pesanan Harian**  
  Sistem progres 5 misi renovasi desa ditambah **Pesanan Harian** acak di Papan Misi yang berganti setiap hari.
- 🌅 **Siklus Waktu & Suasana Desa Hidup**  
  Transisi pencahayaan *Pagi, Siang, Sore, Malam*, lentera jalan & api unggun yang berpendar hangat, partikel daun gugur & kunang-kunang, serta audio SFX & cozy BGM.

---

## 🎮 Kontrol Permainan

| Tombol | Aksi |
| :--- | :--- |
| **`W A S D`** / **Panah** | Menggerakkan karakter |
| **`1 – 5`** / **Scroll Mouse** | Memilih slot aktif pada Hotbar |
| **`I`** / **`Tab`** | Membuka / menutup **Tas Ransel (15 Slot)** |
| **`Space`** / **Klik Kiri** | Menggunakan alat aktif atau menanam & memanen |
| **`E`** | Berinteraksi (Pintu Rumah, *Shipping Bin*, Kios Pasar, Api Unggun, Ternak, NPC, Papan Misi) |
| **`F`** | Memakan hasil panen, masakan, ikan, telur, atau susu untuk memulihkan **Stamina** |
| **`Esc`** | Menutup panel aktif atau membuka **Pause Menu** |
| **`F1`** | Membuka **Menu Demo** (khusus simulasi waktu, stok misi, dan bahan masak saat presentasi) |

---

## 🗺️ Daftar Misi Utama

| Tahap | Nama Misi | Target Pencapaian | Hadiah |
| :---: | :--- | :--- | :--- |
| **Misi 1** | **Petani Pemula** | Panen `3` tanaman & kumpulkan `5` Kayu | **`+100 G`** |
| **Misi 2** | **Nelayan & Peternak** | Tangkap `2` Ikan & kumpulkan `2` Telur | **`+150 G`** |
| **Misi 3** | **Juru Masak & Tetangga Baik** | Masak `2` hidangan & beri `1` Hadiah ke warga | **`+200 G`** |
| **Misi 4** | **Peralatan Tangguh** | Upgrade `1` Alat ke Lv.2 & panen total `8` tanaman | **`+250 G`** |
| **Misi 5** | **Renovasi Agung Desa** | Kumpulkan `600 G`, `15` Kayu, & `12` Batu | **Ending *Cozy Valley Makmur!*** |

---

## 🧩 Arsitektur Modul Kode

| File / Direktori | Peran & Tanggung Jawab |
| :--- | :--- |
| `scenes/title_screen.tscn`<br>`scripts/title_screen.gd` | Menu utama bergaya *pixel art* (*Mulai Bermain* & *Keluar*). |
| `scenes/world.tscn`<br>`scripts/world_game.gd` | Dunia utama desa, kamera 1.65×, siklus siang-malam, *gathering*, memancing, memasak, & hadiah NPC. |
| `scripts/world_player.gd` | Kontrol pemain, sinkronisasi animasi berlapis (*body, hair, tools*), dan deteksi zona interaksi. |
| `scripts/data_registry.gd` | *Autoload* pusat data 11 tanaman, 4 resep masakan, produk ternak/alam, dan harga jual-beli. |
| `scripts/game_state.gd` | *Autoload* state global (Gold, Hari, Jam, Stamina, Hotbar 5 slot, Tas 15 slot, Level Alat, Hati NPC, & 5 Misi). |
| `scripts/farming/farm_manager.gd` | Sistem grid lahan pertanian (cangkul, tanam, siram, pertumbuhan harian, dan panen). |
| `scripts/livestock_manager.gd` | AI patroli ayam & sapi, sistem perawatan (*happiness*), serta produksi telur & susu. |
| `scripts/villager_npc.gd`<br>`scripts/quest_board.gd` | Dialog warga desa, sistem emote hati, dan papan misi utama + pesanan harian. |
| `scripts/hud.gd` | Seluruh antarmuka 9-slice (*TopBar, Hotbar, Tas Ransel, Kios & Upgrade, Dapur Api Unggun, Dialog, Misi, Pause, & Menu Demo F1*). |
| `scripts/sfx_player.gd` | *Autoload* pemutar efek suara (*SFX*) dan musik latar (*BGM loop*). |

---

## 🚀 Cara Menjalankan Proyek

1. Buka **Godot Engine 4.3+** (direkomendasikan versi **4.7**).
2. Klik **Import** dan pilih file `project.godot` di folder utama proyek.
3. Tekan **`F5`** untuk memulai permainan dari *Title Screen*.
