# Karobar Supplies promo video assets

Product images cropped from karobarsupplies.com screenshots, with the discount
badges removed. Each image was upscaled 3x (Lanczos + light sharpening), and the
logo 4x.

| File | Product |
|---|---|
| logo.png | Karobar Supplies logo |
| receipt1.png | HCC-T2P Bluetooth + USB portable receipt printer |
| receipt2.png | PLUSPRO Thermal Receipt Printer (80 mm) |
| label1.png | PLUSPRO Thermal Label Printer |
| scanner1.png | PlusPro PLHW-2065 2D Wireless barcode scanner |
| scanner2.png | Pluspro PLH-2038 2D Wired barcode scanner |
| paper1.png | Thermal Paper 58 mm (pack) |
| paper2.png | PLUSPRO Label Paper 50 x 25 mm |
| paper3.png | 80 mm Thermal Receipt Paper (extra) |
| labelroll.png | Barcode Label Sticker 100 mm roll (extra) |

Add `music.mp3` here (optional) to get background music.

## Making the video

```sh
cd karobar-video
bash make_promo.sh        # -> karobar_promo.mp4 (15 s, 1920x1080, 30 fps)
```

Needs ffmpeg 6+. Edit texts, colours, fonts, scene lengths, music volume and
sound effects (`SFX`, `SFX_VOLUME`) at the top of `make_promo.sh`.
`make_music.sh` regenerates the royalty-free `music.mp3`.
