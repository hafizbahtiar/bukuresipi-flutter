# Google Play listing

Everything Play Console > Grow users > Store presence > **Main store listing** asks for. Default language Malay
(`ms-MY`), translation English (`en-US`): Store listing > Manage translations > add English, paste the English text.

| Field | File / text |
|---|---|
| App name | `Bukuresipi` |
| Short description (max 80) | below |
| Full description (max 4000) | below |
| App icon (512 x 512) | `icon-512.png` (from `assets/brand/icon.png`: full square, Play rounds it) |
| Feature graphic (1024 x 500) | `feature-ms.png` (Malay listing), `feature-en.png` (English) |
| Phone screenshots (2-8, 9:16) | `screens/*.png`, made by `./frame.sh` (below) |

No other app's name or logo (TikTok, Instagram...) in the icon, feature graphic or screenshots: Play's metadata
policy. The description may say which links work, as plain words.

## Short description

ms (64):
```
Simpan resipi dan kedai makan dari media sosial dalam satu buku.
```
en (61):
```
Save recipes and places to eat from social media in one book.
```

## Full description

ms:
```
Jumpa resipi sedap atau kedai makan menarik semasa skrol, kemudian hilang? Bukuresipi menyimpannya untuk anda.

Kongsi siaran dari TikTok, Instagram, Facebook, YouTube atau mana-mana laman web ke Bukuresipi, atau kongsi tangkapan skrin. Kami baca siaran itu dan menyimpannya di tempat yang betul:

RESIPI
• Bahan dan langkah disusun dalam buku resipi anda
• Hanya apa yang ditulis dalam siaran: tiada bahan rekaan
• Tambah bahan ke senarai beli-belah dengan satu ketik; jumlah yang sama dicampur
• Alahan biasa ditandakan bila bahan dikenal pasti

KEDAI MAKAN
• Kedai disimpan pada peta anda, dengan cawangan dan alamat
• Cari kedai simpanan berdekatan
• Dakwaan halal ditunjukkan bersama petikan dan pautan sumbernya
• Penilaian dan ulasan cawangan daripada pengguna lain

KELUARGA
• Kongsi satu buku dengan keluarga (hingga 3 orang)
• Resipi keluarga dan senarai beli-belah bersama
• Tanda "Hanya saya" untuk yang peribadi

DAN LAGI
• Notifikasi bila kongsian anda siap
• Log masuk dengan emel atau Google
• Bahasa Melayu dan Inggeris
• Tiada iklan

Nota: resipi dan butiran kedai dibaca secara automatik dan boleh salah. Halal yang ditunjukkan ialah petikan daripada sumber, bukan pensijilan JAKIM.

Privasi: https://bukuresipi.com/privacy
```

en:
```
Found a great recipe or a place to eat while scrolling, then lost it? Bukuresipi keeps it for you.

Share a post from TikTok, Instagram, Facebook, YouTube or any website to Bukuresipi, or share a screenshot. We read the post and save it in the right place:

RECIPES
• Ingredients and steps laid out in your recipe book
• Only what the post says: no made-up ingredients
• Add ingredients to your shopping list in one tap; the same items are added up
• Common allergens flagged when an ingredient is recognised

PLACES TO EAT
• Restaurants saved on your map, with branches and addresses
• Find your saved places nearby
• Halal claims shown with the quote and a link to the source
• Branch ratings and reviews from other users

FAMILY
• Share one book with your family (up to 3 people)
• Family recipes and a shared shopping list
• Mark anything "Only me" to keep it private

AND MORE
• A notification when your share is ready
• Sign in with email or Google
• Malay and English
• No ads

Note: recipes and restaurant details are read automatically and can be wrong. Halal shown is a quote from the source, not JAKIM certification.

Privacy: https://bukuresipi.com/en/privacy
```

## Screenshots

Take them on the phone (signed in to an account with real content, not the reviewer's empty one), copy them to
`store/screens/raw/`, then `./store/frame.sh`: each becomes a 1080 x 1920 PNG in `store/screens/`. Suggested 6, in
this order (the first 2-3 show in search results):

1. A recipe (ingredients + steps)
2. The map with saved places
3. The book (list of places and recipes)
4. A restaurant's branch with rating and halal quote
5. The shopping list
6. Family

Hide anything private first: other people's names or emails, your notification bar if it shows messages.
