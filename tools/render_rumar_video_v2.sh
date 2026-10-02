#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/outputs/rumar-v2"
GEN="/Users/qbot/.codex/generated_images/019fbe0b-70d8-7050-9618-ae416a8d9764"
mkdir -p "$OUT"
cp "$GEN/exec-3ce495d6-6393-4d0b-ac93-5773bdff149f.png" "$OUT/a.png"
cp "$GEN/exec-6e90e050-ee04-4b5b-b34d-a55fe0319584.png" "$OUT/b.png"
cp "$GEN/exec-c7c7a077-7a96-432f-88eb-41c00f9bd809.png" "$OUT/c.png"
cp "$GEN/exec-154a73b9-fe6e-4cce-98a2-bf90f4f85921.png" "$OUT/d.png"
cp "$GEN/exec-50b2dd47-e327-497d-83a6-ee1197be5ecd.png" "$OUT/e.png"

clip() {
  local src="$1"; local dur="$2"; local copy="$3"; local dst="$4"; local frame="$OUT/${dst%.mp4}.jpg"
  python3 "$ROOT/tools/make_text_frame.py" "$src" "$frame" "$copy"
  ffmpeg -y -loglevel error -loop 1 -i "$frame" -t "$dur" \
    -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,zoompan=z='if(lte(zoom,1.0),1.0,zoom+0.00038)':d=1:s=1080x1920:fps=30" \
    -r 30 -pix_fmt yuv420p -an "$OUT/$dst"
}

clip "$OUT/a.png" 6 "O trabalho começa no terreno." 01.mp4
clip "$OUT/b.png" 8 "Quando o dia está claro, tudo anda." 02.mp4
clip "$OUT/c.png" 10 "Agenda. Cliente. Percurso." 03.mp4
clip "$OUT/d.png" 10 "Menos confusão.\nMais trabalho feito." 04.mp4

python3 "$ROOT/tools/make_final_card.py" "$ROOT/mobile/assets/brand/rumar-mark-v6.png" "$OUT/final.jpg"
ffmpeg -y -loglevel error -loop 1 -i "$OUT/final.jpg" -t 8 -vf "scale=1080:1920" -r 30 -pix_fmt yuv420p -an "$OUT/05.mp4"

ffmpeg -y -loglevel error -i "$OUT/01.mp4" -i "$OUT/02.mp4" -i "$OUT/03.mp4" -i "$OUT/04.mp4" -i "$OUT/05.mp4" \
  -filter_complex "[0:v][1:v]xfade=transition=fade:duration=0.6:offset=5.4[v1];[v1][2:v]xfade=transition=fade:duration=0.6:offset=12.8[v2];[v2][3:v]xfade=transition=fade:duration=0.6:offset=22.2[v3];[v3][4:v]xfade=transition=fade:duration=0.6:offset=31.6[v]" \
  -map "[v]" -r 30 -c:v libx264 -preset medium -crf 18 "$OUT/video.mp4"

ffmpeg -y -loglevel error -f lavfi -i "sine=frequency=82:duration=42" -f lavfi -i "sine=frequency=164:duration=42" \
  -filter_complex "[0:a]volume=0.028,lowpass=f=380[a];[1:a]volume=0.011,lowpass=f=800[b];[a][b]amix=inputs=2,afade=t=in:st=0:d=2,afade=t=out:st=38:d=4" \
  -c:a aac -b:a 192k "$OUT/music.m4a"

ffmpeg -y -loglevel error -i "$OUT/video.mp4" -i "$OUT/music.m4a" -map 0:v -map 1:a -t 42 -c:v copy -c:a aac -movflags +faststart "$OUT/RUMAR-filme-vertical-v2.mp4"
