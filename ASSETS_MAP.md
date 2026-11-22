# ASSETS_MAP — farm-game

> Audit otomatis seluruh file `.png` di `assets/`. Dibuat 2026-11-22 dengan Python 3.11.9 + Pillow 12.0.0.
> Resolusi dibaca langsung dari header PNG; grid frame dideteksi dari profil alpha (lihat §2).

## 1. Ringkasan

| Folder | File PNG | Sprite sheet beranimasi | Frame total |
|---|---:|---:|---:|
| `assets/tileset/` | 2 | — | 4816 tile |
| `assets/characters/` | 186 | 186 | 1958 |
| `assets/crops/` | 78 | 0 | 0 |
| `assets/ui/` | 102 | 0 | 0 |
| `assets/decor/` | 27 | 26 | 259 |
| `assets/animals/` | 24 | 0 | 0 |
| `assets/farm_kit/` | 92 | 0 | 0 |
| `assets/plants/` | 3 | 0 | 0 |
| `assets/villagers/` | 36 | 0 | 0 |
| **Total** | **550** | **212** | **2217** |

Semua 550 file berhasil dibuka (tidak ada PNG korup). Format: 421 RGBA 8-bit + 129 PNG berpalet (indexed).

## 2. Metode audit

1. `PIL.Image.open()` pada setiap file → resolusi `lebar × tinggi`.
2. Alpha channel di-numpy → **bounding box** piksel tidak transparan (lebar/tinggi art sebenarnya).
3. Deteksi grid frame:
   - **Karakter**: semua sheet memakai sel **96×64 px** dengan art 16×16 di tengah. Diverifikasi lewat profil kolom transparan (jarak antar sprite konsisten 96 px) pada human, goblin, dan skeleton.
   - **Dekorasi/VFX**: jumlah frame diambil dari nama file (`*_stripN.png`), lebar sel = lebar gambar ÷ N.
   - **Tileset**: dibagi grid 16×16 px.
   - **Crops & UI**: satu sprite per file (tahap tumbuh = file terpisah, bukan frame).
4. `frame` = `kolom × baris`. Untuk sheet multi-baris, frame dibaca kiri→kanan lalu atas→bawah.

## 3. Konvensi grid Sunnyside World

| Kategori | Sel frame | Art efektif | Pola nama |
|---|---|---|---|
| Karakter (human/goblin/skeleton) | 96×64 | 16×16 | `<layer>_<animasi>_strip<N>.png` |
| Tileset | 16×16 | 16×16 | `spr_tileset_sunnysideworld_16px.png` |
| Crops | 1 file = 1 sprite | 4×7 … 16×16 (tight crop) | `<tanaman>_<00..05>.png` |
| UI / emote | 1 file = 1 sprite | 3×3 … 18×19 | `<nama>.png` |
| Dekorasi | bervariasi | bervariasi | `spr_deco_<objek>_strip<N>.png` |

> **Penting:** sheet karakter **bukan** grid 16×16. Satu frame menempati sel 96×64 px dengan karakter 16×16 px di tengah. Saat membuat `SpriteFrames` di Godot, set **Region → Frame Size = 96 × 64** (bukan 16×16), lalu offset/centered sesuai kebutuhan.

## 4. `assets/tileset/` — 2 file

| File | Resolusi | Grid 16×16 | Jumlah tile |
|---|---|---|---:|
| `tileset/spr_tileset_sunnysideworld_16px.png` | 1024×1024 | 64 × 64 | 4096 |
| `tileset/spr_tileset_sunnysideworld_forest_32px.png` | 320×576 | 20 × 36 | 720 |

- `spr_tileset_sunnysideworld_16px.png` (1024×1024) = tileset utama, 64×64 tile @16 px. Ini yang dipakai untuk `TileSet` utama.
- `spr_tileset_sunnysideworld_forest_32px.png` (320×576) = varian hutan, 20×36 tile. Namanya `32px` tetapi grid-nya tetap kelipatan 16; pakai `Tile Size = 16×16` lalu scale bila perlu, atau set 32×32 bila memang di-render 2×.

## 5. `assets/characters/` — 186 file

Struktur: `human/` (20 animasi × 8 layer), `goblin/` (20 sheet), `skeleton/` (6 sheet).

### 5.1 Human — 160 file (20 animasi × 8 layer)

Layer per animasi: `base`, `bowlhair`, `curlyhair`, `longhair`, `mophair`, `shorthair`, `spikeyhair`, `tools`. Komposisikan layer di atas `base` untuk karakter lengkap.

| Animasi | Folder | Resolusi | Sel | Frame | Strip |
|---|---|---|---|---|---:|
| attack | `human/attack/` | 960×64 | 96×64 | 10 × 1 = **10** | 10 |
| axe | `human/axe/` | 960×64 | 96×64 | 10 × 1 = **10** | 10 |
| carry | `human/carry/` | 768×64 | 96×64 | 8 × 1 = **8** | 8 |
| casting | `human/casting/` | 1440×64 | 96×64 | 15 × 1 = **15** | 15 |
| caught | `human/caught/` | 960×64 | 96×64 | 10 × 1 = **10** | 10 |
| death | `human/death/` | 1248×64 | 96×64 | 13 × 1 = **13** | 13 |
| dig | `human/dig/` | 1248×64 | 96×64 | 13 × 1 = **13** | 13 |
| doing | `human/doing/` | 768×64 | 96×64 | 8 × 1 = **8** | 8 |
| hammering | `human/hammering/` | 2208×64 | 96×64 | 23 × 1 = **23** | 23 |
| hurt | `human/hurt/` | 768×64 | 96×64 | 8 × 1 = **8** | 8 |
| idle | `human/idle/` | 864×64 | 96×64 | 9 × 1 = **9** | 9 |
| jump | `human/jump/` | 864×64 | 96×64 | 9 × 1 = **9** | 9 |
| mining | `human/mining/` | 960×64 | 96×64 | 10 × 1 = **10** | 10 |
| reeling | `human/reeling/` | 1248×64 | 96×64 | 13 × 1 = **13** | 13 |
| roll | `human/roll/` | 960×64 | 96×64 | 10 × 1 = **10** | 10 |
| run | `human/run/` | 768×64 | 96×64 | 8 × 1 = **8** | 8 |
| swimming | `human/swimming/` | 1152×64 | 96×64 | 12 × 1 = **12** | 12 |
| waiting | `human/waiting/` | 864×64 | 96×64 | 9 × 1 = **9** | 9 |
| walking | `human/walking/` | 768×64 | 96×64 | 8 × 1 = **8** | 8 |
| watering | `human/watering/` | 480×64 | 96×64 | 5 × 1 = **5** | 5 |

<details><summary>Daftar lengkap 160 file human</summary>

| File | Resolusi | Sel | Frame |
|---|---|---|---|
| `characters/human/attack/base_attack_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/attack/bowlhair_attack_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/attack/curlyhair_attack_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/attack/longhair_attack_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/attack/mophair_attack_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/attack/shorthair_attack_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/attack/spikeyhair_attack_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/attack/tools_attack_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/axe/base_axe_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/axe/bowlhair_axe_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/axe/curlyhair_axe_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/axe/longhair_axe_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/axe/mophair_axe_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/axe/shorthair_axe_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/axe/spikeyhair_axe_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/axe/tools_axe_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/carry/base_carry_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/carry/bowlhair_carry_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/carry/curlyhair_carry_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/carry/longhair_carry_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/carry/mophair_carry_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/carry/shorthair_carry_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/carry/spikeyhair_carry_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/carry/tools_carry_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/casting/base_casting_strip15.png` | 1440×64 | 96×64 | 15×1 |
| `characters/human/casting/bowlhair_casting_strip15.png` | 1440×64 | 96×64 | 15×1 |
| `characters/human/casting/curlyhair_casting_strip15.png` | 1440×64 | 96×64 | 15×1 |
| `characters/human/casting/longhair_casting_strip15.png` | 1440×64 | 96×64 | 15×1 |
| `characters/human/casting/mophair_casting_strip15.png` | 1440×64 | 96×64 | 15×1 |
| `characters/human/casting/shorthair_casting_strip15.png` | 1440×64 | 96×64 | 15×1 |
| `characters/human/casting/spikeyhair_casting_strip15.png` | 1440×64 | 96×64 | 15×1 |
| `characters/human/casting/tools_casting_strip15.png` | 1440×64 | 96×64 | 15×1 |
| `characters/human/caught/base_caught_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/caught/bowlhair_caught_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/caught/curlyhair_caught_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/caught/longhair_caught_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/caught/mophair_caught_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/caught/shorthair_caught_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/caught/spikeyhair_caught_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/caught/tools_caught_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/death/base_death_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/death/bowlhair_death_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/death/curlyhair_death_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/death/longhair_death_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/death/mophair_death_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/death/shorthair_death_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/death/spikeyhair_death_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/death/tools_death_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/dig/base_dig_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/dig/bowlhair_dig_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/dig/curlyhair_dig_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/dig/longhair_dig_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/dig/mophair_dig_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/dig/shorthair_dig_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/dig/spikeyhair_dig_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/dig/tools_dig_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/doing/base_doing_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/doing/bowlhair_doing_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/doing/curlyhair_doing_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/doing/longhair_doing_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/doing/mophair_doing_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/doing/shorthair_doing_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/doing/spikeyhair_doing_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/doing/tools_doing_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/hammering/base_hamering_strip23.png` | 2208×64 | 96×64 | 23×1 |
| `characters/human/hammering/bowlhair_hamering_strip23.png` | 2208×64 | 96×64 | 23×1 |
| `characters/human/hammering/curlyhair_hamering_strip23.png` | 2208×64 | 96×64 | 23×1 |
| `characters/human/hammering/longhair_hamering_strip23.png` | 2208×64 | 96×64 | 23×1 |
| `characters/human/hammering/mophair_hamering_strip23.png` | 2208×64 | 96×64 | 23×1 |
| `characters/human/hammering/shorthair_hamering_strip23.png` | 2208×64 | 96×64 | 23×1 |
| `characters/human/hammering/spikeyhair_hamering_strip23.png` | 2208×64 | 96×64 | 23×1 |
| `characters/human/hammering/tools_hamering_strip23.png` | 2208×64 | 96×64 | 23×1 |
| `characters/human/hurt/base_hurt_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/hurt/bowlhair_hurt_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/hurt/curlyhair_hurt_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/hurt/longhair_hurt_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/hurt/mophair_hurt_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/hurt/shorthair_hurt_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/hurt/spikeyhair_hurt_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/hurt/tools_hurt_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/idle/base_idle_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/idle/bowlhair_idle_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/idle/curlyhair_idle_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/idle/longhair_idle_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/idle/mophair_idle_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/idle/shorthair_idle_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/idle/spikeyhair_idle_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/idle/tools_idle_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/jump/base_jump_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/jump/bowlhair_jump_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/jump/curlyhair_jump_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/jump/longhair_jump_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/jump/mophair_jump_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/jump/shorthair_jump_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/jump/spikeyhair_jump_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/jump/tools_jump_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/mining/base_mining_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/mining/bowlhair_mining_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/mining/curlyhair_mining_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/mining/longhair_mining_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/mining/mophair_mining_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/mining/shorthair_mining_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/mining/spikeyhair_mining_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/mining/tools_mining_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/reeling/base_reeling_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/reeling/bowlhair_reeling_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/reeling/curlyhair_reeling_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/reeling/longhair_reeling_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/reeling/mophair_reeling_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/reeling/shorthair_reeling_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/reeling/spikeyhair_reeling_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/reeling/tools_reeling_strip13.png` | 1248×64 | 96×64 | 13×1 |
| `characters/human/roll/base_roll_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/roll/bowlhair_roll_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/roll/curlyhair_roll_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/roll/longhair_roll_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/roll/mophair_roll_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/roll/shorthair_roll_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/roll/spikeyhair_roll_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/roll/tools_roll_strip10.png` | 960×64 | 96×64 | 10×1 |
| `characters/human/run/base_run_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/run/bowlhair_run_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/run/curlyhair_run_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/run/longhair_run_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/run/mophair_run_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/run/shorthair_run_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/run/spikeyhair_run_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/run/tools_run_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/swimming/base_swimming_strip12.png` | 1152×64 | 96×64 | 12×1 |
| `characters/human/swimming/bowlhair_swimming_strip12.png` | 1152×64 | 96×64 | 12×1 |
| `characters/human/swimming/curlyhair_swimming_strip12.png` | 1152×64 | 96×64 | 12×1 |
| `characters/human/swimming/longhair_swimming_strip12.png` | 1152×64 | 96×64 | 12×1 |
| `characters/human/swimming/mophair_swimming_strip12.png` | 1152×64 | 96×64 | 12×1 |
| `characters/human/swimming/shorthair_swimming_strip12.png` | 1152×64 | 96×64 | 12×1 |
| `characters/human/swimming/spikeyhair_swimming_strip12.png` | 1152×64 | 96×64 | 12×1 |
| `characters/human/swimming/tools_swimming_strip12.png` | 1152×64 | 96×64 | 12×1 |
| `characters/human/waiting/base_waiting_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/waiting/bowlhair_waiting_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/waiting/curlyhair_waiting_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/waiting/longhair_waiting_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/waiting/mophair_waiting_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/waiting/shorthair_waiting_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/waiting/spikeyhair_waiting_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/waiting/tools_waiting_strip9.png` | 864×64 | 96×64 | 9×1 |
| `characters/human/walking/base_walk_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/walking/bowlhair_walk_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/walking/curlyhair_walk_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/walking/longhair_walk_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/walking/mophair_walk_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/walking/shorthair_walk_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/walking/spikeyhair_walk_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/walking/tools_walk_strip8.png` | 768×64 | 96×64 | 8×1 |
| `characters/human/watering/base_watering_strip5.png` | 480×64 | 96×64 | 5×1 |
| `characters/human/watering/bowlhair_watering_strip5.png` | 480×64 | 96×64 | 5×1 |
| `characters/human/watering/curlyhair_watering_strip5.png` | 480×64 | 96×64 | 5×1 |
| `characters/human/watering/longhair_watering_strip5.png` | 480×64 | 96×64 | 5×1 |
| `characters/human/watering/mophair_watering_strip5.png` | 480×64 | 96×64 | 5×1 |
| `characters/human/watering/shorthair_watering_strip5.png` | 480×64 | 96×64 | 5×1 |
| `characters/human/watering/spikeyhair_watering_strip5.png` | 480×64 | 96×64 | 5×1 |
| `characters/human/watering/tools_watering_strip5.png` | 480×64 | 96×64 | 5×1 |

</details>

### 5.2 Goblin — 20 file

| File | Resolusi | Sel | Kolom × Baris | Frame terdeteksi | `strip` di nama |
|---|---|---|---|---:|---:|
| `characters/goblin/spr_attack_strip10.png` | 864×64 | 96×64 | 9 × 1 | 9 ⚠️ | 10 |
| `characters/goblin/spr_axe_strip10.png` | 960×64 | 96×64 | 10 × 1 | 10 | 10 |
| `characters/goblin/spr_carry_strip8.png` | 768×64 | 96×64 | 8 × 1 | 8 | 8 |
| `characters/goblin/spr_casting_strip15.png` | 960×128 | 96×64 | 10 × 2 | 20 ⚠️ | 15 |
| `characters/goblin/spr_caught_strip10.png` | 960×64 | 96×64 | 10 × 1 | 10 | 10 |
| `characters/goblin/spr_death_strip13.png` | 864×64 | 96×64 | 9 × 1 | 9 ⚠️ | 13 |
| `characters/goblin/spr_dig_strip13.png` | 960×128 | 96×64 | 10 × 2 | 20 ⚠️ | 13 |
| `characters/goblin/spr_doing_strip8.png` | 768×64 | 96×64 | 8 × 1 | 8 | 8 |
| `characters/goblin/spr_hammering_strip23.png` | 960×192 | 96×64 | 10 × 3 | 30 ⚠️ | 23 |
| `characters/goblin/spr_hurt_strip8.png` | 768×64 | 96×64 | 8 × 1 | 8 | 8 |
| `characters/goblin/spr_idle_strip9.png` | 768×64 | 96×64 | 8 × 1 | 8 ⚠️ | 9 |
| `characters/goblin/spr_jump_strip9.png` | 864×64 | 96×64 | 9 × 1 | 9 | 9 |
| `characters/goblin/spr_mining_strip10.png` | 960×64 | 96×64 | 10 × 1 | 10 | 10 |
| `characters/goblin/spr_reeling_strip13.png` | 960×128 | 96×64 | 10 × 2 | 20 ⚠️ | 13 |
| `characters/goblin/spr_roll_strip10.png` | 960×64 | 96×64 | 10 × 1 | 10 | 10 |
| `characters/goblin/spr_run_strip8.png` | 768×64 | 96×64 | 8 × 1 | 8 | 8 |
| `characters/goblin/spr_swimming_strip12.png` | 384×64 | 96×64 | 4 × 1 | 4 ⚠️ | 12 |
| `characters/goblin/spr_waiting_strip9.png` | 768×64 | 96×64 | 8 × 1 | 8 ⚠️ | 9 |
| `characters/goblin/spr_walk_strip8.png` | 768×64 | 96×64 | 8 × 1 | 8 | 8 |
| `characters/goblin/spr_watering_strip5.png` | 480×64 | 96×64 | 5 × 1 | 5 | 5 |

### 5.3 Skeleton — 6 file

| File | Resolusi | Sel | Kolom × Baris | Frame |
|---|---|---|---|---:|
| `characters/skeleton/skeleton_attack_strip7.png` | 672×64 | 96×64 | 7 × 1 | 7 |
| `characters/skeleton/skeleton_death_strip10.png` | 960×64 | 96×64 | 10 × 1 | 10 |
| `characters/skeleton/skeleton_hurt_strip7.png` | 672×64 | 96×64 | 7 × 1 | 7 |
| `characters/skeleton/skeleton_idle_strip6.png` | 576×64 | 96×64 | 6 × 1 | 6 |
| `characters/skeleton/skeleton_jump_strip10.png` | 960×64 | 96×64 | 10 × 1 | 10 |
| `characters/skeleton/skeleton_walk_strip8.png` | 768×64 | 96×64 | 8 × 1 | 8 |

### 5.4 ⚠️ Temuan: nama `strip` pada 9 sheet goblin tidak cocok dengan grid fisik

| File | Frame fisik | `strip` di nama |
|---|---:|---:|
| `characters/goblin/spr_attack_strip10.png` | 9 | 10 |
| `characters/goblin/spr_casting_strip15.png` | 20 | 15 |
| `characters/goblin/spr_death_strip13.png` | 9 | 13 |
| `characters/goblin/spr_dig_strip13.png` | 20 | 13 |
| `characters/goblin/spr_hammering_strip23.png` | 30 | 23 |
| `characters/goblin/spr_idle_strip9.png` | 8 | 9 |
| `characters/goblin/spr_reeling_strip13.png` | 20 | 13 |
| `characters/goblin/spr_swimming_strip12.png` | 4 | 12 |
| `characters/goblin/spr_waiting_strip9.png` | 8 | 9 |

Sheet multi-baris (`casting`, `dig`, `reeling`, `hammering`) punya **slot** lebih banyak daripada frame: mis. `spr_hammering_strip23` = grid 10×3 (30 slot) tetapi hanya 23 frame terisi (10 + 10 + 3). Saat membuat animasi, pakai jumlah frame dari nama (`strip23`), bukan seluruh slot — frame kosong di ujung sheet akan tampak sebagai sprite hilang.

## 6. `assets/crops/` — 78 file

Setiap file = **satu** sprite, **bukan** sheet beranimasi. Tahap tumbuh disimpan sebagai file terpisah `_00` … `_05` (6 tahap per tanaman).

⚠️ **Ukuran tidak seragam.** Sprite di-crop rapat (tight crop) ke bounding box art-nya, jadi resolusinya bervariasi dari **4×7** sampai **16×16 px** — bukan semua 16×16. Saat membuat `Sprite2D`, jangan asumsikan 16×16; pakai ukuran asli lalu `centered = true` + offset bila perlu.

### 6.1 Tahapan tumbuh per tanaman

| Tanaman | Tahap | Resolusi per tahap (00→05) | Frame |
|---|---:|---|---:|
| `beetroot` | 6 | 5×5 → 6×5 → 8×6 → 8×11 → 12×14 → 16×16 | 1 |
| `cabbage` | 6 | 5×5 → 10×7 → 8×7 → 12×10 → 16×13 → 12×11 | 1 |
| `carrot` | 6 | 7×7 → 6×7 → 6×7 → 8×10 → 10×13 → 12×12 | 1 |
| `cauliflower` | 6 | 5×5 → 6×7 → 8×8 → 10×11 → 12×12 → 12×12 | 1 |
| `kale` | 6 | 5×5 → 4×7 → 6×8 → 10×9 → 14×11 → 14×11 | 1 |
| `parsnip` | 6 | 6×6 → 6×6 → 8×7 → 8×8 → 10×14 → 14×14 | 1 |
| `potato` | 6 | 6×6 → 6×6 → 8×8 → 8×11 → 11×15 → 10×10 | 1 |
| `pumpkin` | 6 | 7×7 → 8×7 → 9×9 → 12×11 → 12×14 → 12×14 | 1 |
| `radish` | 6 | 6×6 → 6×6 → 8×7 → 8×10 → 12×15 → 12×15 | 1 |
| `soil` | 4 | 16×12 → 16×12 → 16×12 → 16×12 | 1 |
| `sunflower` | 6 | 7×7 → 10×7 → 11×9 → 11×13 → 13×19 → 13×16 | 1 |
| `wheat` | 6 | 6×6 → 11×7 → 11×10 → 13×14 → 13×16 → 13×13 | 1 |

**Sprite non-tanaman** di folder ini (ikon hasil panen & properti): `crate_base`, `crate_top`, `egg`, `fish`, `milk`, `rock`, `seeds_generic`, `wood`.

> Catatan: `soil` hanya punya 4 tahap (`_00`, `_01`, `_03`, `_04`) — **`soil_02.png` tidak ada** di pack V2.1. Kalau butuh animasi tanah 6 tahap, isi manual atau ulangi salah satu tahap.

### 6.2 Daftar lengkap 78 file crops

| File | Resolusi | Art (bbox) | Frame |
|---|---|---|---:|
| `crops/beetroot_00.png` | 5×5 | 5×5 | 1 |
| `crops/beetroot_01.png` | 6×5 | 6×5 | 1 |
| `crops/beetroot_02.png` | 8×6 | 8×6 | 1 |
| `crops/beetroot_03.png` | 8×11 | 8×11 | 1 |
| `crops/beetroot_04.png` | 12×14 | 12×14 | 1 |
| `crops/beetroot_05.png` | 16×16 | 16×16 | 1 |
| `crops/cabbage_00.png` | 5×5 | 5×5 | 1 |
| `crops/cabbage_01.png` | 10×7 | 10×7 | 1 |
| `crops/cabbage_02.png` | 8×7 | 8×7 | 1 |
| `crops/cabbage_03.png` | 12×10 | 12×10 | 1 |
| `crops/cabbage_04.png` | 16×13 | 16×13 | 1 |
| `crops/cabbage_05.png` | 12×11 | 12×11 | 1 |
| `crops/carrot_00.png` | 7×7 | 7×7 | 1 |
| `crops/carrot_01.png` | 6×7 | 6×7 | 1 |
| `crops/carrot_02.png` | 6×7 | 6×7 | 1 |
| `crops/carrot_03.png` | 8×10 | 8×10 | 1 |
| `crops/carrot_04.png` | 10×13 | 10×13 | 1 |
| `crops/carrot_05.png` | 12×12 | 12×12 | 1 |
| `crops/cauliflower_00.png` | 5×5 | 5×5 | 1 |
| `crops/cauliflower_01.png` | 6×7 | 6×7 | 1 |
| `crops/cauliflower_02.png` | 8×8 | 8×8 | 1 |
| `crops/cauliflower_03.png` | 10×11 | 10×11 | 1 |
| `crops/cauliflower_04.png` | 12×12 | 12×12 | 1 |
| `crops/cauliflower_05.png` | 12×12 | 12×12 | 1 |
| `crops/crate_base.png` | 16×16 | 16×16 | 1 |
| `crops/crate_top.png` | 16×14 | 16×14 | 1 |
| `crops/egg.png` | 10×11 | 10×11 | 1 |
| `crops/fish.png` | 11×11 | 11×11 | 1 |
| `crops/kale_00.png` | 5×5 | 5×5 | 1 |
| `crops/kale_01.png` | 4×7 | 4×7 | 1 |
| `crops/kale_02.png` | 6×8 | 6×8 | 1 |
| `crops/kale_03.png` | 10×9 | 10×9 | 1 |
| `crops/kale_04.png` | 14×11 | 14×11 | 1 |
| `crops/kale_05.png` | 14×11 | 14×11 | 1 |
| `crops/milk.png` | 10×12 | 10×12 | 1 |
| `crops/parsnip_00.png` | 6×6 | 6×6 | 1 |
| `crops/parsnip_01.png` | 6×6 | 6×6 | 1 |
| `crops/parsnip_02.png` | 8×7 | 8×7 | 1 |
| `crops/parsnip_03.png` | 8×8 | 8×8 | 1 |
| `crops/parsnip_04.png` | 10×14 | 10×14 | 1 |
| `crops/parsnip_05.png` | 14×14 | 14×14 | 1 |
| `crops/potato_00.png` | 6×6 | 6×6 | 1 |
| `crops/potato_01.png` | 6×6 | 6×6 | 1 |
| `crops/potato_02.png` | 8×8 | 8×8 | 1 |
| `crops/potato_03.png` | 8×11 | 8×11 | 1 |
| `crops/potato_04.png` | 11×15 | 11×15 | 1 |
| `crops/potato_05.png` | 10×10 | 10×10 | 1 |
| `crops/pumpkin_00.png` | 7×7 | 7×7 | 1 |
| `crops/pumpkin_01.png` | 8×7 | 8×7 | 1 |
| `crops/pumpkin_02.png` | 9×9 | 9×9 | 1 |
| `crops/pumpkin_03.png` | 12×11 | 12×11 | 1 |
| `crops/pumpkin_04.png` | 12×14 | 12×14 | 1 |
| `crops/pumpkin_05.png` | 12×14 | 12×14 | 1 |
| `crops/radish_00.png` | 6×6 | 6×6 | 1 |
| `crops/radish_01.png` | 6×6 | 6×6 | 1 |
| `crops/radish_02.png` | 8×7 | 8×7 | 1 |
| `crops/radish_03.png` | 8×10 | 8×10 | 1 |
| `crops/radish_04.png` | 12×15 | 12×15 | 1 |
| `crops/radish_05.png` | 12×15 | 12×15 | 1 |
| `crops/rock.png` | 10×10 | 10×10 | 1 |
| `crops/seeds_generic.png` | 11×10 | 11×10 | 1 |
| `crops/soil_00.png` | 16×12 | 16×12 | 1 |
| `crops/soil_01.png` | 16×12 | 16×12 | 1 |
| `crops/soil_03.png` | 16×12 | 16×12 | 1 |
| `crops/soil_04.png` | 16×12 | 16×12 | 1 |
| `crops/sunflower_00.png` | 7×7 | 7×7 | 1 |
| `crops/sunflower_01.png` | 10×7 | 10×7 | 1 |
| `crops/sunflower_02.png` | 11×9 | 11×9 | 1 |
| `crops/sunflower_03.png` | 11×13 | 11×13 | 1 |
| `crops/sunflower_04.png` | 13×19 | 13×19 | 1 |
| `crops/sunflower_05.png` | 13×16 | 13×16 | 1 |
| `crops/wheat_00.png` | 6×6 | 6×6 | 1 |
| `crops/wheat_01.png` | 11×7 | 11×7 | 1 |
| `crops/wheat_02.png` | 11×10 | 11×10 | 1 |
| `crops/wheat_03.png` | 13×14 | 13×14 | 1 |
| `crops/wheat_04.png` | 13×16 | 13×16 | 1 |
| `crops/wheat_05.png` | 13×13 | 13×13 | 1 |
| `crops/wood.png` | 11×11 | 11×11 | 1 |

## 7. `assets/ui/` — 102 file

Semua elemen UI adalah sprite tunggal (tidak ada sheet). Folder `9slice_box_white/` berisi 27 potongan 3×3 untuk `NinePatchRect` (3 varian warna: `dt_`, `lt_`, `w_` × 9 posisi).

| Grup | Jumlah | Resolusi | Catatan |
|---|---:|---|---|
| 9-slice box (dt_/lt_/w_) | 27 | 3×3 ×27 | |
| emote / expression | 8 | 4×9 ×1, 7×8 ×1, 9×9 ×1 | |
| bar (green/red/blue) | 21 | 15×7 ×21 | |
| happiness | 4 | 7×8 ×4 | |
| ikon alat | 9 | 13×13 ×3, 14×14 ×2, 15×13 ×1 | |
| lainnya (kursor, panah, label, selectbox, dll.) | 33 | 8×9 ×4, 11×12 ×2, 10×13 ×2 | |

<details><summary>Daftar lengkap 102 file UI</summary>

| File | Resolusi | Art (bbox) |
|---|---|---|
| `ui/9slice_box_white/dt_box_9slice_bc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/dt_box_9slice_bl.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/dt_box_9slice_br.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/dt_box_9slice_c.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/dt_box_9slice_lc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/dt_box_9slice_rc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/dt_box_9slice_tc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/dt_box_9slice_tl.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/dt_box_9slice_tr.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/lt_box_9slice_bc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/lt_box_9slice_bl.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/lt_box_9slice_br.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/lt_box_9slice_c.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/lt_box_9slice_lc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/lt_box_9slice_rc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/lt_box_9slice_tc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/lt_box_9slice_tl.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/lt_box_9slice_tr.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/w_box_9slice_bc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/w_box_9slice_bl.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/w_box_9slice_br.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/w_box_9slice_c.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/w_box_9slice_lc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/w_box_9slice_rc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/w_box_9slice_tc.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/w_box_9slice_tl.png` | 3×3 | 3×3 |
| `ui/9slice_box_white/w_box_9slice_tr.png` | 3×3 | 3×3 |
| `ui/arrow_left.png` | 11×12 | 11×12 |
| `ui/arrow_right.png` | 11×12 | 11×12 |
| `ui/arrow_up-1.png` | 10×13 | 10×13 |
| `ui/arrow_up.png` | 10×13 | 10×13 |
| `ui/axe.png` | 15×13 | 15×13 |
| `ui/basket.png` | 12×12 | 12×12 |
| `ui/bluebar_00.png` | 15×7 | 15×7 |
| `ui/bluebar_01.png` | 15×7 | 15×7 |
| `ui/bluebar_02.png` | 15×7 | 15×7 |
| `ui/bluebar_03.png` | 15×7 | 15×7 |
| `ui/bluebar_04.png` | 15×7 | 15×7 |
| `ui/bluebar_05.png` | 15×7 | 15×7 |
| `ui/cancel.png` | 11×11 | 11×11 |
| `ui/confirm.png` | 12×11 | 12×11 |
| `ui/cursor_01.png` | 11×19 | 11×19 |
| `ui/cursor_02.png` | 11×14 | 11×14 |
| `ui/cursor_03.png` | 12×13 | 12×13 |
| `ui/cursor_04.png` | 12×14 | 12×14 |
| `ui/cursor_05.png` | 10×15 | 10×15 |
| `ui/expression_alerted.png` | 4×9 | 4×9 |
| `ui/expression_attack.png` | 7×8 | 7×8 |
| `ui/expression_chat.png` | 9×9 | 9×9 |
| `ui/expression_confused-1.png` | 8×9 | 8×9 |
| `ui/expression_confused.png` | 7×10 | 7×10 |
| `ui/expression_love.png` | 9×8 | 9×8 |
| `ui/expression_stress.png` | 7×7 | 7×7 |
| `ui/expression_working.png` | 7×9 | 7×9 |
| `ui/greenbar_00.png` | 15×7 | 15×7 |
| `ui/greenbar_01.png` | 15×7 | 15×7 |
| `ui/greenbar_02.png` | 15×7 | 15×7 |
| `ui/greenbar_03.png` | 15×7 | 15×7 |
| `ui/greenbar_04.png` | 15×7 | 15×7 |
| `ui/greenbar_05.png` | 15×7 | 15×7 |
| `ui/greenbar_06-1.png` | 15×7 | 15×7 |
| `ui/greenbar_06.png` | 15×7 | 15×7 |
| `ui/hammer.png` | 13×13 | 13×13 |
| `ui/hand_closed_01.png` | 9×9 | 9×9 |
| `ui/hand_closed_02.png` | 13×12 | 13×12 |
| `ui/hand_open_01.png` | 11×11 | 11×11 |
| `ui/hand_open_02.png` | 14×14 | 14×14 |
| `ui/happiness_01.png` | 7×8 | 7×8 |
| `ui/happiness_02.png` | 7×8 | 7×8 |
| `ui/happiness_03.png` | 7×8 | 7×8 |
| `ui/happiness_04.png` | 7×8 | 7×8 |
| `ui/indicator.png` | 8×6 | 8×6 |
| `ui/itemdisc_01.png` | 18×19 | 18×19 |
| `ui/itemdisc_02.png` | 17×18 | 17×18 |
| `ui/label_left.png` | 4×13 | 4×13 |
| `ui/label_middle.png` | 16×13 | 16×13 |
| `ui/label_right.png` | 4×13 | 4×13 |
| `ui/pickaxe.png` | 13×13 | 13×13 |
| `ui/plan alt.png` | 12×12 | 12×12 |
| `ui/plant.png` | 10×11 | 10×11 |
| `ui/playercount.png` | 13×14 | 13×14 |
| `ui/redbar_00.png` | 15×7 | 15×7 |
| `ui/redbar_01.png` | 15×7 | 15×7 |
| `ui/redbar_02.png` | 15×7 | 15×7 |
| `ui/redbar_03.png` | 15×7 | 15×7 |
| `ui/redbar_04.png` | 15×7 | 15×7 |
| `ui/redbar_05.png` | 15×7 | 15×7 |
| `ui/redbar_06.png` | 15×7 | 15×7 |
| `ui/rod alt.png` | 16×14 | 16×14 |
| `ui/rod.png` | 15×14 | 15×14 |
| `ui/sandtimer.png` | 8×11 | 8×11 |
| `ui/search.png` | 16×16 | 13×13 |
| `ui/select_dots.png` | 5×6 | 5×6 |
| `ui/select_dots_large.png` | 6×7 | 6×7 |
| `ui/selectbox_bl.png` | 8×9 | 8×9 |
| `ui/selectbox_br.png` | 8×9 | 8×9 |
| `ui/selectbox_tl.png` | 8×9 | 8×9 |
| `ui/selectbox_tr.png` | 8×9 | 8×9 |
| `ui/shovel.png` | 14×14 | 14×14 |
| `ui/stopwatch.png` | 10×12 | 10×12 |
| `ui/sword.png` | 14×14 | 14×14 |
| `ui/water.png` | 13×13 | 13×13 |

</details>

## 8. `assets/decor/` — 27 file (tambahan, di luar 4 folder yang diminta)

| File | Resolusi | Sel | Kolom × Baris | Frame |
|---|---|---|---|---:|
| `decor/animals/spr_deco_bird_01_strip4.png` | 64×16 | 16×16 | 4 × 1 | 4 |
| `decor/animals/spr_deco_blinking_strip12.png` | 192×16 | 16×16 | 12 × 1 | 12 |
| `decor/animals/spr_deco_chicken_01_strip4.png` | 128×32 | 32×32 | 4 × 1 | 4 |
| `decor/animals/spr_deco_cow_strip4.png` | 128×32 | 32×32 | 4 × 1 | 4 |
| `decor/animals/spr_deco_duck_01_strip4.png` | 64×16 | 16×16 | 4 × 1 | 4 |
| `decor/animals/spr_deco_pig_01_strip4.png` | 128×32 | 32×32 | 4 × 1 | 4 |
| `decor/animals/spr_deco_sheep_01_strip4.png` | 128×32 | 32×32 | 4 × 1 | 4 |
| `decor/other/spr_deco_coracle_land.png` | 32×30 | — | 1 × 1 | 1 |
| `decor/other/spr_deco_coracle_strip4.png` | 192×37 | 48×37 | 4 × 1 | 4 |
| `decor/other/spr_deco_windmill_strip9.png` | 1008×112 | 112×112 | 9 × 1 | 9 |
| `decor/other/spr_deco_windmill_withshadow_strip9.png` | 1008×112 | 112×112 | 9 × 1 | 9 |
| `decor/other/spr_deco_windmillshadow_strip9.png` | 1008×112 | 112×112 | 9 × 1 | 9 |
| `decor/plants/spr_deco_mushroom_blue_01_strip4.png` | 64×16 | 16×16 | 4 × 1 | 4 |
| `decor/plants/spr_deco_mushroom_blue_02_strip4.png` | 64×16 | 16×16 | 4 × 1 | 4 |
| `decor/plants/spr_deco_mushroom_blue_03_strip4.png` | 64×16 | 16×16 | 4 × 1 | 4 |
| `decor/plants/spr_deco_mushroom_red_01_strip4.png` | 64×16 | 16×16 | 4 × 1 | 4 |
| `decor/plants/spr_deco_tree_01_strip4.png` | 128×34 | 32×34 | 4 × 1 | 4 |
| `decor/plants/spr_deco_tree_02_strip4.png` | 112×43 | 28×43 | 4 × 1 | 4 |
| `decor/vfx/chimney_smoke/chimneysmoke_01_strip30.png` | 450×37 | 15×37 | 30 × 1 | 30 |
| `decor/vfx/chimney_smoke/chimneysmoke_02_strip30.png` | 300×30 | 10×30 | 30 × 1 | 30 |
| `decor/vfx/chimney_smoke/chimneysmoke_03_strip30.png` | 540×21 | 18×21 | 30 × 1 | 30 |
| `decor/vfx/chimney_smoke/chimneysmoke_04_strip30.png` | 600×32 | 20×32 | 30 × 1 | 30 |
| `decor/vfx/chimney_smoke/chimneysmoke_05_strip30.png` | 720×19 | 24×19 | 30 × 1 | 30 |
| `decor/vfx/fire/spr_deco_fire_01_strip4.png` | 20×10 | 5×10 | 4 × 1 | 4 |
| `decor/vfx/fire/spr_deco_fire_02_strip4.png` | 32×12 | 8×12 | 4 × 1 | 4 |
| `decor/vfx/glint/spr_deco_glint_01_strip6.png` | 42×7 | 7×7 | 6 × 1 | 6 |
| `decor/vfx/glint/spr_deco_glint_02_strip4.png` | 28×7 | 7×7 | 4 × 1 | 4 |

## 9. Lampiran: paket legacy di `assets/` (bukan Sunnyside)

Folder ini sudah ada sebelum impor Sunnyside. Resolusi diaudit, tetapi grid frame **tidak** ter-encode di nama file sehingga tidak diestimasi per frame.

| Folder | File | Resolusi |
|---|---:|---|
| `assets/animals/` | 24 | 192×256 ×10, 32×32 ×5, 384×512 ×4, 96×128 ×2 |
| `assets/farm_kit/` | 92 | 16×8 ×22, 32×8 ×12, 72×24 ×10, 48×24 ×8 |
| `assets/plants/` | 3 | 1840×2445 ×1, 768×432 ×1, 288×224 ×1 |
| `assets/villagers/` | 36 | 192×48 ×18, 48×48 ×6, 96×48 ×6, 288×48 ×6 |

## 10. Pengaturan `project.godot`

### 10.1 Kondisi awal

```ini
[display]
window/size/viewport_width=640
window/size/viewport_height=360
window/stretch/mode="canvas_items"

[rendering]
textures/canvas_textures/default_texture_filter=0
```

Sudah benar untuk pixel art: viewport 640×360, `canvas_items`, filter Nearest (0). Yang belum ada: `aspect` dan `scale_mode`, sehingga window bisa di-resize ke skala non-integer dan piksel jadi tidak rata.

### 10.2 Setelah perbaikan (sekarang)

```ini
[display]

window/size/viewport_width=640
window/size/viewport_height=360
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/stretch/scale_mode="integer"

[rendering]

textures/canvas_textures/default_texture_filter=0
```

| Setting | Nilai | Alasan |
|---|---|---|
| `viewport_width` × `height` | 640 × 360 | 16:9, pas untuk tile 16 px (40 × 22.5 tile terlihat) |
| `stretch/mode` | `canvas_items` | UI dan sprite di-scale bersama; teks tetap tajam |
| `stretch/aspect` | `keep` | Menjaga 16:9, tidak ada area terpotong |
| `stretch/scale_mode` | `integer` | Skala hanya 1×, 2×, 3×… → piksel tetap kotak |
| `default_texture_filter` | `0` (Nearest) | Wajib untuk pixel art, mencegah blur |

> Alternatif resolusi: **480×270** (30 × 16.9 tile) memberi tampilan lebih dekat. Ganti kedua nilai viewport bila ingin. Jangan lupa `scale_mode="integer"` tetap dipakai.

## 11. Catatan & langkah berikutnya

1. **Import preset**: untuk semua PNG, set *Import → Filter = Nearest* (sudah global lewat project setting) dan *Mipmaps = off*. Bisa dibatch lewat `Project Settings → Import Defaults → texture`.
2. **SpriteFrames karakter**: frame size **96×64**, bukan 16×16. Animasi human dibuat dari layer `base` + satu layer rambut + `tools`; jangan campur `tools_*` ke body.
3. **Goblin**: pakai jumlah frame dari nama file, bukan jumlah slot grid (lihat §5.4).
4. **Tileset**: `spr_tileset_sunnysideworld_16px.png` untuk `TileSet` 16 px. Buat `TileSetAtlasSource` dengan texture region 16×16.
5. **Crops**: `_00` … `_05` = 6 tahap tumbuh. Ikon hasil panen (milk, egg, fish, wood, rock) juga ada di folder yang sama — pisahkan saat membuat item database.
6. **UI 9-slice**: `9slice_box_white/` sudah dipotong per 3×3 sel; susun di `NinePatchRect` atau impor ulang sebagai satu atlas.
