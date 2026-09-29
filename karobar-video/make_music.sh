#!/usr/bin/env bash
# Generates an original, royalty-free 15 s upbeat track (music.mp3) with ffmpeg only.
# 120 BPM, chords C - G - Am - F (one bar = 2 s), kick + hi-hat + arpeggio + pad.
set -euo pipefail

B='mod(floor(t/2),4)'                       # current chord (0=C 1=G 2=Am 3=F)
ch() { echo "if(eq($B,0),$1,if(eq($B,1),$2,if(eq($B,2),$3,$4)))"; }
R=$(ch 261.63 196.00 220.00 174.61)        # chord root
T3=$(ch 329.63 246.94 261.63 220.00)       # third
T5=$(ch 392.00 293.66 329.63 261.63)       # fifth
S='mod(floor(t*4),4)'                       # 16th-note step in the arpeggio
NOTE="if(eq($S,0),$R,if(eq($S,1),$T3,if(eq($S,2),$T5,2*$R)))"

KICK="0.9*sin(2*PI*(45*mod(t,0.5)+1.6*(1-exp(-mod(t,0.5)*30))))*exp(-mod(t,0.5)*9)"
HAT="0.10*(random(0)*2-1)*exp(-mod(t+0.25,0.5)*45)"
CLAP="0.16*(random(1)*2-1)*exp(-mod(t+1,1)*22)*gte(t,2)"
ARP="0.16*sin(2*PI*${NOTE}*t)*exp(-mod(t,0.25)*9)*gte(t,0.5)"
PAD="0.07*(sin(2*PI*${R}/2*t)+sin(2*PI*${T3}/2*t)+sin(2*PI*${T5}/2*t))"
BASS="0.22*sin(2*PI*${R}/4*t)*(0.6+0.4*exp(-mod(t,0.5)*6))"

ffmpeg -hide_banner -loglevel error -y -f lavfi \
  -i "aevalsrc=exprs='${KICK}+${HAT}+${CLAP}+${ARP}+${PAD}+${BASS}':s=44100:d=15" \
  -af "aecho=0.8:0.5:250:0.2,highpass=f=35,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=44100,afade=t=in:d=0.3,afade=t=out:st=13.5:d=1.5,aformat=channel_layouts=stereo" \
  -c:a libmp3lame -b:a 192k music.mp3
echo "Done: music.mp3"
