#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/outputs/rumar"
GEN="/Users/qbot/.codex/generated_images/019fbe0b-70d8-7050-9618-ae416a8d9764"
FONT="/System/Library/Fonts/SFNS.ttf"
mkdir -p "$OUT"

cp "$GEN/exec-3ce495d6-6393-4d0b-ac93-5773bdff149f.png" "$OUT/scene-1.png"
cp "$GEN/exec-241afd00-cf9a-431b-a023-f61c17fc1b1f.png" "$OUT/scene-2.png"
cp "$GEN/exec-c7c7a077-7a96-432f-88eb-41c00f9bd809.png" "$OUT/scene-3.png"
cp "$GEN/exec-154a73b9-fe6e-4cce-98a2-bf90f4f85921.png" "$OUT/scene-4.png"

say -v 'Eddy' -o "$OUT/voice.aiff" \
  'Chamadas, mensagens, moradas, urgências. E o dia ainda nem começou. Com a RUMAR, cada trabalho fica claro antes de saíres. Vês a agenda, os trabalhos em aberto, a informação de cada cliente, o tempo previsto e o percurso. E quando entra um novo pedido, não fica perdido numa conversa. Menos tempo perdido a organizar. Mais foco em atender clientes e fazer o trabalho acontecer. A RUMAR foi criada para equipas técnicas que querem ter controlo do dia. Vê como funciona numa demonstração rápida.'

ffmpeg -y -loglevel error -f lavfi -i "sine=frequency=110:duration=42" -f lavfi -i "sine=frequency=220:duration=42" \
  -filter_complex "[0:a]volume=0.018[a0];[1:a]volume=0.010[a1];[a0][a1]amix=inputs=2:duration=longest,lowpass=f=700,afade=t=in:st=0:d=2,afade=t=out:st=38:d=4" \
  -ar 44100 -ac 2 "$OUT/music.wav"

make_clip() {
  local img="$1" dur="$2" text="$3" out="$4"
  local annotated="${out%.mp4}-annotated.jpg"
  python3 "$ROOT/tools/make_text_frame.py" "$img" "$annotated" "$text"
  ffmpeg -y -loglevel error -loop 1 -i "$annotated" -t "$dur" -vf \
    "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,zoompan=z='min(zoom+0.0008,1.06)':d=1:s=1080x1920:fps=30" \
    -r 30 -pix_fmt yuv420p -an "$out"
}

make_clip "$OUT/scene-1.png" 6 "O teu dia começa a trabalhar...\\nou a tentar organizá-lo?" "$OUT/c1.mp4"
make_clip "$OUT/scene-2.png" 6 "Tudo o que precisas.\\nNum só lugar." "$OUT/c2.mp4"
make_clip "$OUT/scene-3.png" 13 "Agenda do dia    •    Cliente    •    Percurso" "$OUT/c3.mp4"
make_clip "$OUT/scene-4.png" 9 "Menos confusão.\\nMais controlo." "$OUT/c4.mp4"

python3 "$ROOT/tools/make_final_card.py" "$ROOT/mobile/assets/brand/rumar-mark-v6.png" "$OUT/final.jpg"
ffmpeg -y -loglevel error -loop 1 -i "$OUT/final.jpg" -t 8 \
  -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920" \
  -r 30 -pix_fmt yuv420p -an "$OUT/c5.mp4"

printf "file '%s'\nfile '%s'\nfile '%s'\nfile '%s'\nfile '%s'\n" "$OUT/c1.mp4" "$OUT/c2.mp4" "$OUT/c3.mp4" "$OUT/c4.mp4" "$OUT/c5.mp4" > "$OUT/concat.txt"
ffmpeg -y -loglevel error -f concat -safe 0 -i "$OUT/concat.txt" -i "$OUT/music.wav" \
  -filter_complex "[1:a]volume=0.35[music]" \
  -map 0:v:0 -map "[music]" -t 42 -r 30 -c:v libx264 -preset medium -crf 19 -c:a aac -b:a 192k -movflags +faststart \
  "$OUT/RUMAR-apresentacao-vertical.mp4"

echo "$OUT/RUMAR-apresentacao-vertical.mp4"
