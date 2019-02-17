#!/bin/bash
# curl, wget, montage

ox=2500
oy=2000

URL=$1
# https://gallica.bnf.fr/ark:/12148/btv1b53020937m/f1.zoom
#ID=$(echo "$URL" | sed -r "s#.+ark:/[0-9]+/(.+)(.item|.zoom)\#?#\1#g" | tr "/" ".")

ID=$(curl -s "$URL" | grep -Eo "/ark:/[0-9]+/[^.]+\.(item|zoom|image)" | head -n 1 | sed -r "s#/ark:/[0-9]+/([^.]+)\..+#\1#g" | tr "/" ".")

json=$(curl -sL "https://gallica.bnf.fr/proxy?method=M&ark=$ID" | tr "," "\n")
l=$(echo "$json" | grep levels | sed -r 's/.+: *([0-9]+).*/\1/g')
width=$(echo "$json" | grep width | sed -r 's/.+: *([0-9]+).*/\1/g')
height=$(echo "$json" | grep height | sed -r 's/.+: *([0-9]+).*/\1/g')

echo level:$l width:$width height:$height >&2

TMPDIR=$(mktemp -d)
echo "temp directory is $TMPDIR" >&2

y=0
i=0
x=0
while [ $y -lt $height ]
do
	x=0
	while [ $x -lt $width ]
	do
		wget -c -O $TMPDIR/"tmp_"$(printf "%05d" $i)".jpg" "https://gallica.bnf.fr/proxy?method=R&ark=$ID&l=$l&r=$y,$x,$oy,$ox"
		i=$(( $i + 1 ))
		x=$(( $x + $ox ))
	done
	y=$(( $y + $oy ))
done

i=$(( $i - 1 ))
montage $TMPDIR/tmp_*.jpg -mode concatenate -tile $(( $x / $ox ))x$(( $y / $oy )) "$ID.jpg"
echo "wrote ./$ID.jpg" >&2
rm -r $TMPDIR
