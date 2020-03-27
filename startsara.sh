#!/bin/bash

EXTDIS="HDMI-0"

TAGS="123456789"
LEFTSYM="<"
RIGHTSYM=">"
BARFG="#ffffff"
BARBG="#000000"
BARFONT="Noto Sans:size=10"
BARH=18
BARX=0
# Make sure to adjust for BARH if you put the bar on the bottom! (i.e. y_orig = 1080-18)
BARY=0

INFF="/tmp/saralemon.fifo"
# Clear out any stale fifos
test -e "$INFF" && ! test -p "$INFF" && sudo rm "$INFF"
test -p "$INFF" || sudo mkfifo -m 777 "$INFF"

# Pass MONLINE, TAGS, LEFTSYM, RIGHTSYM
MakeTagStr () {
	local MONLINE="$1"
	local TAGS="$2"
	local LEFTSYM="$3"
	local RIGHTSYM="$4"

	local TAGSTR=""

	# 0:00000000:00000000:[]= -> 00000000:00000000:[]=
	MONLINE="$(cut -d':' -f2-4 <<<"$MONLINE")"
	local ISDESKOCC="$(cut -d':' -f1 <<<"$MONLINE")"
	local ISDESKSEL="$(cut -d':' -f2 <<<"$MONLINE")"
	local LAYOUTSYM="$(cut -d':' -f3 <<<"$MONLINE")"

	for (( i=0; i<${#ISDESKOCC}; i++ )); do
		if [ ${ISDESKSEL:$i:1} -eq 1 ]; then
			TAGSTR="${TAGSTR} $LEFTSYM${TAGS:$i:1}$RIGHTSYM "
		elif [ ${ISDESKOCC:$i:1} -eq 1 ]; then
			TAGSTR="${TAGSTR}   ${TAGS:$i:1}   "
		fi
	done
	TAGSTR="${TAGSTR}  $LAYOUTSYM"

	echo "$TAGSTR"
}

while read line; do
	MULTI=$(xrandr -q | grep "$EXTDIS" | awk -F" " '{ print $2 }')

	# if line is sara info
	if [[ "${line:0:1}" =~ ^[0-4].* ]]; then
		# monitor 0 (lemonbar says it's 1)
		MONLINE0="$(cut -d' ' -f1 <<<"$line")"
		TAGSTR0="$(MakeTagStr $MONLINE0 $TAGS $LEFTSYM $RIGHTSYM)"

		if [ "$MULTI" = "connected" ]; then
			BARW=3840
			# monitor 1 (lemonbar says it's 0)
			MONLINE1="$(cut -d' ' -f2 <<<"$line")"
			TAGSTR1="$(MakeTagStr $MONLINE1 $TAGS $LEFTSYM $RIGHTSYM)"
		else
			BARW=1920
		fi
	# else, line is sbar info
	else
		BARSTATS="$line"
	fi

	if [ "$MULTI" = "connected" ]; then
		printf "%s\n" "%{S0}%{l}$TAGSTR1%{r}$BARSTATS%{S1}%{l}$TAGSTR0%{r}$BARSTATS"
	else
		printf "%s\n" "%{l}$TAGSTR0%{r}$BARSTATS"
	fi
done < "$INFF" | lemonbar -g "$BARW"x"$BARH"+"$BARX"+"$BARY" -d -f "$BARFONT" -p -B "$BARBG" -F "$BARFG" &

# pull information from sara
exec sara > "$INFF"
