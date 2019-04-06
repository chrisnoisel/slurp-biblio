#!/bin/bash

BASE_URL='https://basedescollections.musee-armee.fr'

function usage
{
	echo -e "usage:" >&2
	echo -e "\t"$(basename "$0")" <https://basedescollections.musee-armee.fr/ark:/...>" >&2
	echo -e "\t"$(basename "$0")" <ark:/...>" >&2
}

function maxLevel
{
	# $1 width
	# $2 height
	max=$(( $1 > $2 ? $1 : $2 ))
	
	level=$(echo "l($max)/l(2)" | bc -l | xargs printf '%.6f\n')
	level_floor=$(echo "$level" | tr , . | cut -d '.' -f 1)
	# ceil()
	if [[ "$level" == *".000000" ]]
	then
		echo "$level_floor"
	else
		echo $(( $level_floor + 1 ))
	fi
}

function getRegion
{
	tilesize=$1
	overlap=$2
	w=$3
	h=$4
	x=$5
	y=$6
	
	sizew=$(( $w - ($x * $tilesize) > $tilesize ? $tilesize : $w - ($x * $tilesize) ))
	sizeh=$(( $h - ($y * $tilesize) > $tilesize ? $tilesize : $h - ($y * $tilesize) ))
	
	ox=$(( ($x * $tilesize) > $overlap ? $overlap : 0 ))
	oy=$(( ($y * $tilesize) > $overlap ? $overlap : 0 ))
	
	echo '['$sizew'x'$sizeh'+'$ox'+'$oy']'
}

https://basedescollections.musee-armee.fr/notice?id=h%3A%3Aark%3A%2F66008%2F2018820&posInSet=1&queryId=N-eff35ca4-1d3e-42bc-b0ba-9e9f9c65ae5a

ark_long=$(echo "$1" | sed 's/%3A/:/g' | sed 's#%2F#/#g' | grep -Eo "ark:/[^.&]+")
ark=$(echo "$ark_long" | cut -d '/' -f 1-3)

if [ -z "$ark_long" ]
then
	echo "error: no ark reference found" >&2
	usage
	exit 1
fi

deepZoomManifest_url="$BASE_URL"$(curl -s 'https://basedescollections.musee-armee.fr/in/imageReader.xhtml?id='"$ark"'&updateUrl=updateUrl2062&ark=/'"$ark_long" | grep deepZoomManifest | tr ',' '\n' | grep deepZoomManifest | tr -d '" ' | cut -d : -f 2)
deepZoomManifest=$(curl -s "$deepZoomManifest_url" | tr ' ' '\n' | tr -d '"')

WIDTH=$(echo "$deepZoomManifest" | grep "Width" | cut -d = -f 2-)
HEIGHT=$(echo "$deepZoomManifest" | grep "Height" | cut -d = -f 2-)
FORMAT=$(echo "$deepZoomManifest" | grep "Format" | cut -d = -f 2-)
OVERLAP=$(echo "$deepZoomManifest" | grep "Overlap" | cut -d = -f 2-)
TILESIZE=$(echo "$deepZoomManifest" | grep "TileSize" | cut -d = -f 2-)
MAXLEVEL=$(maxLevel $WIDTH $HEIGHT)

IMAGE_URL_BASE=$(echo "$deepZoomManifest_url" | sed 's#.xml#_files/#')

TMPDIR=$(mktemp -d)
echo "temp directory is $TMPDIR" >&2

echo "width: $WIDTH" >&2
echo "height: $HEIGHT" >&2

y=0
i=0
x=0
while [ $(( $y * $TILESIZE )) -lt $HEIGHT ]
do
	x=0
	while [ $(( $x * $TILESIZE )) -lt $WIDTH ]
	do
		tile_url="$IMAGE_URL_BASE"$MAXLEVEL/$x'_'$y".jpg"
		tile_path="$TMPDIR/tmp_"$(printf "%05d" $i)".jpg"
		imgs[$i]="$tile_path""$(getRegion $TILESIZE $OVERLAP $WIDTH $HEIGHT $x $y)"
		
		echo "$tile_url -> $tile_path" >&2
		curl -s -o "$tile_path" "$tile_url"
		
		i=$(( $i + 1 ))
		x=$(( $x + 1 ))
	done
	y=$(( $y + 1 ))
done

montage "${imgs[@]}" -mode concatenate -tile $(( $x ))x$(( $y )) $(echo "$ark" | tr -d ':' | tr '/' '-')".jpg"
echo "done." >&2
rm -r $TMPDIR
