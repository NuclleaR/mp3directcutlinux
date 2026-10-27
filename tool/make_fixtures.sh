#!/usr/bin/env bash
# Regenerates the MP3 test fixtures in test/fixtures/.
# Signal: 10 s of a 440 Hz sine with digital silence at 3–4 s and 7–8 s.
set -euo pipefail

out=test/fixtures
mkdir -p "$out"
tone="if(between(t,3,4)+between(t,7,8),0,0.5*sin(2*PI*440*t))"
ff=(ffmpeg -hide_banner -loglevel error -y)

"${ff[@]}" -f lavfi -i "aevalsrc='${tone}|${tone}':s=44100:d=10" \
  -c:a libmp3lame -b:a 128k -id3v2_version 3 -write_id3v1 1 \
  -metadata title="Tale One" -metadata artist="Test Artist" \
  "$out/cbr_stereo_44k.mp3"

"${ff[@]}" -f lavfi -i "aevalsrc='${tone}':s=22050:d=10" \
  -c:a libmp3lame -q:a 5 -id3v2_version 4 -metadata title="Казка" \
  "$out/vbr_mono_22k.mp3"

"${ff[@]}" -f lavfi -i "aevalsrc='${tone}|${tone}':s=44100:d=10" \
  -c:a libmp3lame -b:a 128k -map_metadata -1 -id3v2_version 0 -write_xing 0 \
  "$out/plain_cbr.mp3"

ls -l "$out"
