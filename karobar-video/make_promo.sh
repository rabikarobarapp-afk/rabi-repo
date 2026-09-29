#!/usr/bin/env bash
# =============================================================================
#  Karobar Supplies - 15 second promo video (1920x1080, 30 fps)
#  Uses ONLY ffmpeg (6.0+). Works in Git Bash (Windows), macOS and Linux.
#
#  Run from the folder that contains the images:
#      bash make_promo.sh
# =============================================================================
set -euo pipefail

# ----------------------------------------------------------------------------
# 1. EDITABLE SETTINGS
# ----------------------------------------------------------------------------
OUT="karobar_promo.mp4"
W=1920; H=1080; FPS=30

# Brand colours
GREEN="0x2FA36B"        # primary
DARK_GREEN="0x1E7A4F"   # gradients / shadows
YELLOW="0xFFC21A"       # discount badges
TEXT_DARK="0x111111"
TEXT_SOFT="0x4A4F4C"
BG_LIGHT="0xF5F7F6"

# Fonts - leave empty to auto-detect, or set a path, e.g.
#   FONT="C:/Windows/Fonts/arialbd.ttf"   FONT_REGULAR="C:/Windows/Fonts/arial.ttf"
FONT=""
FONT_REGULAR=""

# Texts
INTRO_TAGLINE="Your Complete POS & Billing Partner"
FOOTER_URL="karobarsupplies.com"
CTA_TEXT="Shop now at karobarsupplies.com"
DELIVERY_TEXT="Delivery all over Nepal"

# Category scenes: title line 1 | title line 2 | subtitle | badge
S2_T1="Receipt";        S2_T2="Printers";  S2_SUB="Bluetooth • USB • 58mm & 80mm"; S2_BADGE="UP TO 11% OFF"
S3_T1="Label";          S3_T2="Printers";  S3_SUB="Barcode & Shipping Labels";     S3_BADGE="6% OFF"
S4_T1="Barcode";        S4_T2="Scanners";  S4_SUB="2D Wired & Wireless";           S4_BADGE="UP TO 18% OFF"
S5_T1="Thermal Paper";  S5_T2="& Labels";  S5_SUB="58mm • 80mm • Label Rolls";     S5_BADGE="UP TO 17% OFF"

# Audio: background music (music.mp3, optional) and motion sound effects
MUSIC_VOLUME=0.55       # 0.0 - 1.0
SFX=1                   # 1 = whooshes / pops / chimes on the animations, 0 = off
SFX_VOLUME=0.9          # 0.0 - 1.5

# Scene lengths (seconds, each must be a multiple of 1/FPS) and transition length.
# Total = D1+D2+D3+D4+D5+D6 - 5*XF  ->  2.8*5 + 3.0 - 5*0.4 = 17.0 - 2.0 = 15.0 s
D1=2.8; D2=2.8; D3=2.8; D4=2.8; D5=2.8; D6=3.0
XF=0.4

# ----------------------------------------------------------------------------
# 2. CHECKS
# ----------------------------------------------------------------------------
command -v ffmpeg >/dev/null 2>&1 || {
  echo "ERROR: ffmpeg not found. Install it (brew install ffmpeg / winget install ffmpeg / apt install ffmpeg)." >&2
  exit 1; }

IMAGES=(logo.png receipt1.png receipt2.png label1.png scanner1.png scanner2.png paper1.png paper2.png)
missing=0
for f in "${IMAGES[@]}"; do
  [ -f "$f" ] || { echo "ERROR: missing image: $f" >&2; missing=1; }
done
[ "$missing" -eq 0 ] || { echo "Put all images in: $(pwd)" >&2; exit 1; }

# Font auto-detection (first file that exists wins)
pick_font() {
  for f in "$@"; do [ -f "$f" ] && { echo "$f"; return; }; done
  echo ""
}
[ -n "$FONT" ] || FONT=$(pick_font \
  "Poppins-Bold.ttf" "Montserrat-Bold.ttf" \
  "C:/Windows/Fonts/arialbd.ttf" "/c/Windows/Fonts/arialbd.ttf" \
  "/System/Library/Fonts/Supplemental/Arial Bold.ttf" "/Library/Fonts/Arial Bold.ttf" \
  "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" \
  "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" \
  "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf")
[ -n "$FONT_REGULAR" ] || FONT_REGULAR=$(pick_font \
  "Poppins-Regular.ttf" "Montserrat-Regular.ttf" \
  "C:/Windows/Fonts/arial.ttf" "/c/Windows/Fonts/arial.ttf" \
  "/System/Library/Fonts/Supplemental/Arial.ttf" "/Library/Fonts/Arial.ttf" \
  "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf" \
  "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf" \
  "/usr/share/fonts/dejavu/DejaVuSans.ttf")
[ -n "$FONT" ] && [ -n "$FONT_REGULAR" ] || {
  echo "ERROR: no font found. Set FONT and FONT_REGULAR at the top of the script." >&2; exit 1; }

# Git Bash style /c/... -> C:/... (ffmpeg.exe does not understand /c/)
winpath() { case "$1" in /[a-zA-Z]/*) echo "${1:1:1}:${1:2}";; *) echo "$1";; esac; }
# Escape a path for use inside a filter option: '\' -> '/', ':' -> '\:'
ffesc() { winpath "$1" | sed -e 's#\\#/#g' -e 's#:#\\:#g'; }
FB=$(ffesc "$FONT")
FR=$(ffesc "$FONT_REGULAR")
echo "Bold font:    $FONT"
echo "Regular font: $FONT_REGULAR"

TMP="_karobar_tmp"
rm -rf "$TMP"; mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

FF=(ffmpeg -hide_banner -loglevel error -y)
# High-quality intermediate encode for the scene clips
ENC=(-c:v libx264 -preset veryfast -crf 12 -pix_fmt yuv420p -r "$FPS")

# All texts go through text files: no escaping problems with : , ' % &
txt() { printf '%s' "$2" > "$TMP/$1.txt"; }

# Rounded-corner alpha mask for geq (radius R, anti-aliased edge)
mask() {
  local R=$1
  echo "255*clip($R+0.5-hypot(max(0\,abs(X-W/2+0.5)-(W/2-$R))\,max(0\,abs(Y-H/2+0.5)-(H/2-$R)))\,0\,1)"
}

# Ease-out cubic progress 0->1, starting at time $1 and lasting $2 seconds
ease() { echo "(1-pow(1-clip((t-$1)/$2\,0\,1)\,3))"; }

# ----------------------------------------------------------------------------
# 3. PREPARE STILL ELEMENTS (cards, shadows, badges) - rendered once as PNG
# ----------------------------------------------------------------------------
echo "[1/4] Preparing product cards..."

# make_card SRC OUT CARD_W CARD_H MODE(fit|cover)
#   fit   = whole product on a white card with padding (white-background photos)
#   cover = photo fills the card (photos with their own background)
make_card() {
  local src=$1 out=$2 cw=$3 ch=$4 mode=$5 pad=36
  local place
  if [ "$mode" = "cover" ]; then
    place="[0]crop=iw*0.97:ih*0.97,scale=${cw}:${ch}:force_original_aspect_ratio=increase,crop=${cw}:${ch}[p];[1][p]overlay=0:0"
  else
    # colorlevels (before crop: crop+colorlevels crashes some ffmpeg builds) pushes the near-white photo background to pure white so it blends into the card
    place="[0]colorlevels=rimax=0.965:gimax=0.965:bimax=0.965,crop=iw*0.97:ih*0.97,scale=$((cw-2*pad)):$((ch-2*pad)):force_original_aspect_ratio=decrease[p];[1][p]overlay=(W-w)/2:(H-h)/2"
  fi
  "${FF[@]}" -i "$src" -f lavfi -i "color=white:s=${cw}x${ch}" -filter_complex \
    "${place},format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='$(mask 28)'" \
    -frames:v 1 "$out"
}

# make_shadow OUT CARD_W CARD_H  -> soft shadow PNG, 50 px bigger on each side
make_shadow() {
  local out=$1 cw=$2 ch=$3 m=50
  "${FF[@]}" -f lavfi -i "color=black@0.0:s=$((cw+2*m))x$((ch+2*m)),format=rgba" \
    -f lavfi -i "color=black:s=${cw}x${ch}" -filter_complex \
    "[1]format=rgba,geq=r=0:g=0:b=0:a='0.30*$(mask 28)'[s];[0][s]overlay=${m}:${m},format=yuva444p,gblur=sigma=18" \
    -frames:v 1 "$out"
}

# make_pill OUT TEXT BG FG FONTSIZE HEIGHT -> rounded pill with centred text
make_pill() {
  local out=$1 text=$2 bg=$3 fg=$4 fs=$5 ph=$6
  local pw=$(( ${#text} * fs * 62 / 100 + ph ))
  txt "$(basename "$out" .png)" "$text"
  "${FF[@]}" -f lavfi -i "color=${bg}:s=${pw}x${ph}" -vf \
    "drawtext=fontfile='${FB}':textfile='$TMP/$(basename "$out" .png).txt':expansion=none:fontsize=${fs}:fontcolor=${fg}:x=(w-text_w)/2:y=(h-text_h)/2,format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='$(mask $((ph/2)))'" \
    -frames:v 1 "$out"
}

# Card sizes: pairs are 440x440, the single label printer is 620x620
C2=440; C1=620
make_card receipt1.png "$TMP/c_receipt1.png" $C2 $C2 cover
make_card receipt2.png "$TMP/c_receipt2.png" $C2 $C2 fit
make_card label1.png   "$TMP/c_label1.png"   $C1 $C1 fit
make_card scanner1.png "$TMP/c_scanner1.png" $C2 $C2 fit
make_card scanner2.png "$TMP/c_scanner2.png" $C2 $C2 fit
make_card paper1.png   "$TMP/c_paper1.png"   $C2 $C2 cover
make_card paper2.png   "$TMP/c_paper2.png"   $C2 $C2 fit
make_card logo.png     "$TMP/c_logo.png"     760 330 fit
make_shadow "$TMP/sh_$C2.png" $C2 $C2
make_shadow "$TMP/sh_$C1.png" $C1 $C1
make_shadow "$TMP/sh_logo.png" 760 330

make_pill "$TMP/b2.png" "$S2_BADGE" "$YELLOW" black 40 84
make_pill "$TMP/b3.png" "$S3_BADGE" "$YELLOW" black 40 84
make_pill "$TMP/b4.png" "$S4_BADGE" "$YELLOW" black 40 84
make_pill "$TMP/b5.png" "$S5_BADGE" "$YELLOW" black 40 84
make_pill "$TMP/delivery.png" "$DELIVERY_TEXT" "$YELLOW" black 44 92

txt tagline "$INTRO_TAGLINE"; txt url "$FOOTER_URL"; txt cta "$CTA_TEXT"
for s in 2 3 4 5; do
  eval "txt s${s}t1 \"\$S${s}_T1\"; txt s${s}t2 \"\$S${s}_T2\"; txt s${s}sub \"\$S${s}_SUB\""
done

# ----------------------------------------------------------------------------
# 4. RENDER SCENES
# ----------------------------------------------------------------------------
echo "[2/4] Rendering scenes..."

# Brand-green diagonal gradient background (very slow rotation = subtle motion)
green_bg() {
  echo "gradients=s=${W}x${H}:r=${FPS}:d=$1:c0=${GREEN}:c1=${DARK_GREEN}:x0=0:y0=0:x1=${W}:y1=${H}:speed=0.002"
}

# --- Scene 1: INTRO ---------------------------------------------------------
# Logo card scales 85% -> 100% with fade-in; tagline slides up + fades in.
LOGO_S="(0.85+0.15*$(ease 0.1 0.8))"
"${FF[@]}" -f lavfi -i "$(green_bg $D1)" \
  -loop 1 -framerate $FPS -t $D1 -i "$TMP/c_logo.png" \
  -loop 1 -framerate $FPS -t $D1 -i "$TMP/sh_logo.png" \
  -filter_complex "
    [1]format=rgba,fade=t=in:st=0.1:d=0.5:alpha=1,
       scale=w='trunc(760*${LOGO_S}/2)*2':h=-2:eval=frame[logo];
    [2]format=rgba,fade=t=in:st=0.1:d=0.5:alpha=1[sh];
    [0][sh]overlay=x='(W-w)/2':y='(H-h)/2-80+14'[b1];
    [b1][logo]overlay=x='(W-w)/2':y='(H-h)/2-80'[b2];
    [b2]drawtext=fontfile='${FB}':textfile='$TMP/tagline.txt':expansion=none:fontsize=58:fontcolor=white:
       x=(w-text_w)/2:y='h/2+150+50*(1-$(ease 0.7 0.7))':alpha='$(ease 0.7 0.7)'
  " -t $D1 "${ENC[@]}" "$TMP/scene1.mp4"

# --- Scenes 2-5: CATEGORY TEMPLATE -----------------------------------------
# category_scene N DUR MIRROR(0|1) ANIM(right|left|up) CARD_SIZE CARD_A [CARD_B]
#   MIRROR=0: text left, images right.  MIRROR=1: images left, text right.
category_scene() {
  local n=$1 d=$2 mirror=$3 anim=$4 cs=$5 ca=$6 cb=${7:-}
  local tx rx rw
  if [ "$mirror" = "0" ]; then tx=130; rx=900; else tx=1120; rx=80; fi
  rw=940                                   # width of the image region

  # Card positions (two cards side by side, or one centred)
  local y0=$(( (H - cs) / 2 + 20 )) xa xb
  if [ -n "$cb" ]; then
    xa=$(( rx + (rw - 2*cs - 40) / 2 )); xb=$(( xa + cs + 40 ))
  else
    xa=$(( rx + (rw - cs) / 2 ))
  fi

  # Entrance: returns overlay x and y expressions for a card at (X0,Y0) with delay
  entrance() {
    local x0=$1 dl=$2 e; e=$(ease "$dl" 0.6)
    case "$anim" in
      right) echo "x='${x0}+(${W}+60-${x0})*(1-${e})-(w-${cs})/2':y='${y0}-(h-${cs})/2'";;
      left)  echo "x='${x0}-(${x0}+${cs}+60)*(1-${e})-(w-${cs})/2':y='${y0}-(h-${cs})/2'";;
      up)    echo "x='${x0}-(w-${cs})/2':y='${y0}+(${H}+60-${y0})*(1-${e})-(h-${cs})/2'";;
    esac
  }
  # Shadow follows the card (50 px margin, 14 px lower)
  shadow_pos() {
    local x0=$1 dl=$2 e; e=$(ease "$dl" 0.6)
    case "$anim" in
      right) echo "x='${x0}-50+(${W}+60-${x0})*(1-${e})':y='${y0}-50+14'";;
      left)  echo "x='${x0}-50-(${x0}+${cs}+60)*(1-${e})':y='${y0}-50+14'";;
      up)    echo "x='${x0}-50':y='${y0}-50+14+(${H}+60-${y0})*(1-${e})'";;
    esac
  }

  # Slow zoom 1.00 -> 1.05 over the whole scene
  local zoom="scale=w='trunc(${cs}*(1+0.05*t/${d})/2)*2':h=-2:eval=frame"

  # Badge: scale "pop" with overshoot, anchored at the image region's top-right corner
  local bdl=0.9 bw bx by right
  local btext; eval "btext=\$S${n}_BADGE"
  bw=$(( ${#btext} * 40 * 62 / 100 + 84 ))   # same width formula as make_pill
  if [ -n "$cb" ]; then right=$(( xb + cs )); else right=$(( xa + cs )); fi
  bx=$(( right - bw / 2 + 30 )); by=$(( y0 - 10 ))   # sits on the last card's top-right corner
  local bp="clip((t-${bdl})/0.45\,0\,1)"
  local bscale="max(0.02\,(1-pow(1-${bp}\,3))+0.25*sin(PI*${bp}))"

  local inputs=(-f lavfi -i "color=${BG_LIGHT}:s=${W}x${H}:r=${FPS}:d=${d}"
                -loop 1 -framerate $FPS -t "$d" -i "$TMP/sh_${cs}.png"
                -loop 1 -framerate $FPS -t "$d" -i "$TMP/${ca}.png"
                -loop 1 -framerate $FPS -t "$d" -i "$TMP/b${n}.png")
  [ -n "$cb" ] && inputs+=(-loop 1 -framerate $FPS -t "$d" -i "$TMP/${cb}.png")

  local g=""
  # Background decoration: green bar at the bottom, soft green circle behind the images
  g+="[0]drawbox=x=0:y=${H}-14:w=${W}:h=14:color=${GREEN}:t=fill,"
  g+="drawtext=fontfile='${FB}':textfile='$TMP/url.txt':expansion=none:fontsize=30:fontcolor=${GREEN}:x=${tx}:y=${H}-80[bg];"
  # Card A + its shadow
  g+="[1]format=rgba,split[sha][shb];"
  g+="[2]format=rgba,${zoom}[ca];"
  g+="[bg][sha]overlay=$(shadow_pos $xa 0.15)[v1];"
  g+="[v1][ca]overlay=$(entrance $xa 0.15)[v2];"
  if [ -n "$cb" ]; then
    # Card B arrives 0.2 s later (stagger)
    g+="[4]format=rgba,${zoom}[cb];"
    g+="[v2][shb]overlay=$(shadow_pos $xb 0.35)[v3];"
    g+="[v3][cb]overlay=$(entrance $xb 0.35)[v4];"
  else
    g+="[shb]nullsink;[v2]null[v4];"
  fi
  # Badge pop
  g+="[3]format=rgba,scale=w='trunc(${bw}*${bscale}/2)*2':h=-2:eval=frame[bd];"
  g+="[v4][bd]overlay=x='${bx}-w/2':y='${by}-h/2':enable='gte(t,${bdl})'[v5];"
  # Title (2 lines), growing underline, subtitle
  g+="[v5]drawtext=fontfile='${FB}':textfile='$TMP/s${n}t1.txt':expansion=none:fontsize=84:fontcolor=${TEXT_DARK}:"
  g+="x=${tx}:y='300+40*(1-$(ease 0.25 0.5))':alpha='$(ease 0.25 0.5)',"
  g+="drawtext=fontfile='${FB}':textfile='$TMP/s${n}t2.txt':expansion=none:fontsize=84:fontcolor=${TEXT_DARK}:"
  g+="x=${tx}:y='400+40*(1-$(ease 0.35 0.5))':alpha='$(ease 0.35 0.5)',"
  g+="drawbox=x=${tx}:y=520:w='max(1\,170*$(ease 0.55 0.5))':h=10:color=${GREEN}:t=fill:enable='gte(t,0.55)',"
  g+="drawtext=fontfile='${FR}':textfile='$TMP/s${n}sub.txt':expansion=none:fontsize=38:fontcolor=${TEXT_SOFT}:"
  g+="x=${tx}:y='566+30*(1-$(ease 0.7 0.5))':alpha='$(ease 0.7 0.5)'"

  "${FF[@]}" "${inputs[@]}" -filter_complex "$g" -t "$d" "${ENC[@]}" "$TMP/scene${n}.mp4"
}

category_scene 2 $D2 0 right $C2 c_receipt1 c_receipt2
category_scene 3 $D3 1 left  $C1 c_label1
category_scene 4 $D4 0 up    $C2 c_scanner1 c_scanner2
category_scene 5 $D5 1 left  $C2 c_paper1 c_paper2

# --- Scene 6: OUTRO ---------------------------------------------------------
# Logo card at the top, pulsing CTA, yellow delivery pill.
"${FF[@]}" -f lavfi -i "$(green_bg $D6)" \
  -loop 1 -framerate $FPS -t $D6 -i "$TMP/c_logo.png" \
  -loop 1 -framerate $FPS -t $D6 -i "$TMP/delivery.png" \
  -filter_complex "
    [1]format=rgba,scale=620:-2,fade=t=in:st=0:d=0.4:alpha=1[logo];
    [2]format=rgba,fade=t=in:st=0.9:d=0.4:alpha=1[pill];
    [0][logo]overlay=x='(W-w)/2':y='150-30*(1-$(ease 0 0.6))'[a];
    [a]drawtext=fontfile='${FB}':textfile='$TMP/cta.txt':expansion=none:fontsize=78:fontcolor=white:
       x=(w-text_w)/2:y='560+40*(1-$(ease 0.4 0.5))':
       alpha='$(ease 0.4 0.5)*(0.925+0.075*cos(2*PI*1.4*max(t-0.9\,0)))'[b];
    [b][pill]overlay=x='(W-w)/2':y='720+20*(1-$(ease 0.9 0.5))'
  " -t $D6 "${ENC[@]}" "$TMP/scene6.mp4"

# ----------------------------------------------------------------------------
# 5. JOIN WITH XFADE
# ----------------------------------------------------------------------------
# offset_k = (D1 + ... + Dk) - k*XF      (when transition k starts)
#   off1 = 2.8               - 0.4 =  2.4
#   off2 = 2.8+2.8           - 0.8 =  4.8
#   off3 = 2.8*3             - 1.2 =  7.2
#   off4 = 2.8*4             - 1.6 =  9.6
#   off5 = 2.8*5             - 2.0 = 12.0
#   total = off5 + D6 = 12.0 + 3.0 = 15.0 s
echo "[3/4] Joining scenes with transitions..."
calc() { awk "BEGIN{printf \"%.3f\", $1}"; }
O1=$(calc "$D1-$XF")
O2=$(calc "$D1+$D2-2*$XF")
O3=$(calc "$D1+$D2+$D3-3*$XF")
O4=$(calc "$D1+$D2+$D3+$D4-4*$XF")
O5=$(calc "$D1+$D2+$D3+$D4+$D5-5*$XF")
TOTAL=$(calc "$O5+$D6")
FADE_ST=$(calc "$TOTAL-0.4")
echo "    offsets: $O1 $O2 $O3 $O4 $O5   total: ${TOTAL}s"

# --- Sound effects (generated with ffmpeg, no audio files needed) ----------
SFX_IN=(); SFX_CHAIN=""; SFX_LABELS=""; n_sfx=0
if [ "$SFX" = "1" ]; then
  echo "    generating sound effects..."
  # whoosh: pink noise, band-limited, swells up then falls away (scene transitions)
  "${FF[@]}" -f lavfi -i "anoisesrc=c=pink:r=48000:a=0.9:d=0.6" -af \
    "highpass=f=250,lowpass=f=3200,volume='if(lt(t,0.32),pow(t/0.32,2),exp(-(t-0.32)*11))':eval=frame,aformat=channel_layouts=stereo" \
    "$TMP/whoosh.wav"
  # swish: short airy white noise (cards and text sliding in)
  "${FF[@]}" -f lavfi -i "anoisesrc=c=white:r=48000:a=0.5:d=0.35" -af \
    "highpass=f=1800,lowpass=f=7500,volume='if(lt(t,0.09),t/0.09,exp(-(t-0.09)*16))':eval=frame,aformat=channel_layouts=stereo" \
    "$TMP/swish.wav"
  # pop: rising "bubble" tone (badges popping in)
  "${FF[@]}" -f lavfi -i "aevalsrc=exprs='0.9*sin(2*PI*(380*t+2600*t*t))*exp(-t*28)*min(t/0.002\,1)':s=48000:d=0.2" \
    -af "aformat=channel_layouts=stereo" "$TMP/pop.wav"
  # chime: bell-like E6 + B6 with a short echo (logo and call to action)
  "${FF[@]}" -f lavfi -i "aevalsrc=exprs='0.30*(sin(2*PI*1318.5*t)+0.6*sin(2*PI*1975.5*t)+0.25*sin(2*PI*2637*t))*exp(-t*4)*min(t/0.004\,1)':s=48000:d=1.3" \
    -af "aecho=0.8:0.6:110:0.28,aformat=channel_layouts=stereo" "$TMP/chime.wav"

  # Each scene starts (its t=0) at the start of the transition into it:
  #   scene1 = 0, scene2 = O1, scene3 = O2, scene4 = O3, scene5 = O4, scene6 = O5
  # event: file  time(s)  volume
  EVENTS="
    chime  0.10            1.8
    swish  0.70            1.6
    whoosh $(calc "$O1-0.05") 2.4
    swish  $(calc "$O1+0.40") 1.6
    pop    $(calc "$O1+0.95") 0.9
    whoosh $(calc "$O2-0.05") 2.4
    pop    $(calc "$O2+0.95") 0.9
    whoosh $(calc "$O3-0.05") 2.4
    swish  $(calc "$O3+0.40") 1.6
    pop    $(calc "$O3+0.95") 0.9
    whoosh $(calc "$O4-0.05") 2.4
    swish  $(calc "$O4+0.40") 1.6
    pop    $(calc "$O4+0.95") 0.9
    whoosh $(calc "$O5-0.05") 2.4
    chime  $(calc "$O5+0.40") 1.8
    pop    $(calc "$O5+0.95") 0.9
  "
  idx=7   # inputs 0-5 = scenes, 6 = music/silence
  while read -r f tm vol; do
    [ -n "${f:-}" ] || continue
    ms=$(awk "BEGIN{printf \"%d\", $tm*1000}")
    SFX_IN+=(-i "$TMP/$f.wav")
    SFX_CHAIN+="[${idx}:a]adelay=${ms}|${ms},volume=$(calc "$vol*$SFX_VOLUME")[e${n_sfx}];"
    SFX_LABELS+="[e${n_sfx}]"
    idx=$((idx+1)); n_sfx=$((n_sfx+1))
  done <<< "$EVENTS"
fi

# --- Background: music.mp3 (trimmed, faded) or silence ---------------------
if [ -f music.mp3 ]; then
  AUDIO_IN=(-i music.mp3)
  MUSIC="[6:a]aresample=48000,aformat=channel_layouts=stereo,apad,atrim=0:${TOTAL},afade=t=in:st=0:d=0.5,afade=t=out:st=$(calc "$TOTAL-1.5"):d=1.5,volume=${MUSIC_VOLUME}[bgm];"
else
  AUDIO_IN=(-f lavfi -t "$TOTAL" -i anullsrc=r=48000:cl=stereo)
  MUSIC="[6:a]atrim=0:${TOTAL}[bgm];"
fi
AUDIO_IN+=("${SFX_IN[@]+"${SFX_IN[@]}"}")
# Mix music + effects (normalize=0 keeps every level as set), limiter prevents clipping
AFILTER="${MUSIC}${SFX_CHAIN}[bgm]${SFX_LABELS}amix=inputs=$((n_sfx+1)):duration=first:normalize=0,alimiter=limit=0.95,atrim=0:${TOTAL}[aout]"

echo "[4/4] Encoding final video..."
"${FF[@]}" \
  -i "$TMP/scene1.mp4" -i "$TMP/scene2.mp4" -i "$TMP/scene3.mp4" \
  -i "$TMP/scene4.mp4" -i "$TMP/scene5.mp4" -i "$TMP/scene6.mp4" \
  "${AUDIO_IN[@]}" \
  -filter_complex "
    [0:v]settb=AVTB,fps=${FPS},format=yuv420p[s1];
    [1:v]settb=AVTB,fps=${FPS},format=yuv420p[s2];
    [2:v]settb=AVTB,fps=${FPS},format=yuv420p[s3];
    [3:v]settb=AVTB,fps=${FPS},format=yuv420p[s4];
    [4:v]settb=AVTB,fps=${FPS},format=yuv420p[s5];
    [5:v]settb=AVTB,fps=${FPS},format=yuv420p[s6];
    [s1][s2]xfade=transition=smoothleft:duration=${XF}:offset=${O1}[x1];
    [x1][s3]xfade=transition=slideleft:duration=${XF}:offset=${O2}[x2];
    [x2][s4]xfade=transition=smoothup:duration=${XF}:offset=${O3}[x3];
    [x3][s5]xfade=transition=slideleft:duration=${XF}:offset=${O4}[x4];
    [x4][s6]xfade=transition=circleopen:duration=${XF}:offset=${O5}[x5];
    [x5]fade=t=out:st=${FADE_ST}:d=0.4[vout];
    ${AFILTER}
  " -map "[vout]" -map "[aout]" -t "$TOTAL" \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -r "$FPS" \
  -c:a aac -b:a 192k -movflags +faststart "$OUT"

echo "Done: $OUT"
