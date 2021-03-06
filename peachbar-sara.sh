#!/bin/bash

if test -f "$HOME/.config/peachbar/peachbar.conf"; then
	. "$HOME/.config/peachbar/peachbar.conf"
else
	echo "Missing config file: $HOME/.config/peachbar/peachbar.conf"
	exit -1
fi


# ------------------------------------------
# Parse sara output
# ------------------------------------------
# TODO: TAGS spacing does not look okay with arbitrary tags! Need to standardize.
#	1. Determine which tag has the most characters
#	2. Give that one 2 spaces of padding
#	3. Add the difference to everyone else
#		a. What about odd numbers?
ParseSara() {
	LTBUTTONSTART="%{A:sarasock 'setlayout tile':}%{A3:sarasock 'setlayout monocle':}"
	LTBUTTONEND="%{A}%{A}"

	# Pass MONLINE, TAGS, SELTAGS, OCCTAGS
	MONLINE="$1"
	TAGS="$2"
	SELTAGS="$3"
	OCCTAGS="$4"

	# In case user wants to be less specific with symbols
	test -z "$SELTAGS" && SELTAGS="$TAGS"
	test -z "$OCCTAGS" && OCCTAGS="$TAGS"

	TAGSTR="%{B$INFOBG}"

	# MonNum:OccupiedDesks:SelectedDesks:LayoutSymbol
	# 0:000000000:000000000:[]= -> 000000000:000000000:[]=
	MONLINE="$(echo $MONLINE | cut -d':' -f2-4)"
	ISDESKOCC="$(echo $MONLINE | cut -d':' -f1)"
	ISDESKSEL="$(echo $MONLINE | cut -d':' -f2)"
	LAYOUTSYM="$(echo $MONLINE | cut -d':' -f3)"

	# TODO: is ${#STRING} portable?
	# TODO: options for all tags or just occupied
	for (( i=0; i<${#ISDESKOCC}; i++ )); do
		# TODO: does not play nice with nested clickables. Causes tags to disappear on extra monitor.
		#TAGBUTTONSTART="%{A:sarasock 'view $i':}%{A3:sarasock 'toggleview $i':}"
		#TAGBUTTONEND="%{A}%{A}"

		TAGBUTTONSTART="%{A:sarasock 'view $i':}"
		TAGBUTTONEND="%{A}"

		if test "$(echo $ISDESKSEL | cut -c$((i + 1)))" -eq 1; then
			TMPFG=$SELCOLFG
			TMPBG=$SELCOLBG
			TMPTAGS=$SELTAGS
		elif test "$(echo $ISDESKOCC | cut -c$((i + 1)))" -eq 1; then
			TMPFG=$OCCCOLFG
			TMPBG=$OCCCOLBG
			TMPTAGS=$OCCTAGS
		else
			TMPFG=$INFOFG
			TMPBG=$INFOBG
			TMPTAGS=$TAGS
		fi

		TAGSTR="${TAGSTR}%{F$TMPFG}%{B$TMPBG}${TAGBUTTONSTART}   $(echo -e $TMPTAGS | cut -d':' -f$((i + 1)) )   ${TAGBUTTONEND}%{B-}%{F-}"
	done
	TAGSTR="${TAGSTR}${LTBUTTONSTART}  $LAYOUTSYM  ${LTBUTTONEND}%{B-}"

	echo -e "${TAGSTR}"
}


# ------------------------------------------
# Grab information and print it out
# ------------------------------------------
GrabNPrint() {
	MONLINE=$1
	MULTI=$(xrandr -q | grep "$EXTDIS" | cut -d' ' -f2)

	if [[ "${MONLINE:0:1}" =~ ^[0-4].* ]]; then
	#if test "${MONLINE:0:4}" = "SARA"; then
		# Take only the part inside the {SARA}___{SARA-} delims
		#MONLINE="$(echo $MONLINE | sed 's/.*{SARA}//' | sed 's/{SARA-}.*//')"
		#MONLINE0="$(cut -d'|' -f1 <<<"$MONLINE")"

		# monitor 0 (lemonbar says it's 1)
		MONLINE0="$(cut -d' ' -f1 <<<"$MONLINE")"
		TAGSTR0="$(ParseSara $MONLINE0 $TAGS $SELTAGS $OCCTAGS)"

		if test "$MULTI" = "connected"; then
			#MONLINE1="$(cut -d'|' -f2 <<<"$MONLINE")"

			# monitor 1 (lemonbar says it's 0)
			MONLINE1="$(cut -d' ' -f2 <<<"$MONLINE")"
			TAGSTR1="$(ParseSara $MONLINE1 $TAGS $SELTAGS $OCCTAGS)"
		fi

	else
		BARSTATS="$MONLINE"
	fi

	if test "$MULTI" = "connected"; then
		printf "%s\n" "%{B$BARBG}%{S0}%{l}${TAGSTR1}%{r}$BARSTATS%{S1}%{l}${TAGSTR0}%{r}$BARSTATS%{B-}"
	else
		printf "%s\n" "%{B$BARBG}%{l}${TAGSTR0}%{r}$BARSTATS%{B-}"
		#echo -e "%{B$BARBG}%{l}${TAGSTR0}%{r}$BARSTATS%{B-}\n"
	fi
}

# ------------------------------------------
# Initialization
# ------------------------------------------
# Kill other peachbar-sara.sh instances
# For some reason, pgrep and 'peachbar-*.sh'
#	don't play nice - something about the
#	[.].
PEACHPIDS="$(pgrep "peachbar-sara")"
for PEACHPID in $PEACHPIDS; do
	! test $PEACHPID = $$ && kill -9 $PEACHPID
done


# ------------------------------------------
# Main loop
# ------------------------------------------
# Reload config file on signal
# TODO: doesn't quite work
#	Because I'm not piping anything into GrabNPrint - it needs $line
trap ". $HOME/.config/peachbar/peachbar.conf; GrabNPrint" SIGUSR2
trap 'exit 1' SIGTERM
while read line; do
	GrabNPrint "$line"
done
