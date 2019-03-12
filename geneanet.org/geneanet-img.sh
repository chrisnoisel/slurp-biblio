#!/bin/bash
# curl, wget, montage

BASE_URL="https://en.geneanet.org"

function usage
{
	echo -e "usage:\n\t$0 <geneanet document url>" >&2
}

function strip_xml
{
	grep "$1" | cut -d = -f 2- | sed -E 's/^"(.*)"$/\1/g'
}

ox=2500
oy=2000

if [ -z "$1" ]
then
	echo 'error: missing url' >&2
	usage
	exit 1
fi

URL=$1
#example : https://en.geneanet.org/archives/registres/view/12949/18?idcollection=12949&legacy_script=/archives/registres/view/index.php&page=18

# clean up
collection_id=0
page_num=1
pathParams=$(echo "$URL" | grep -Eo 'view/[0-9]+(/[0-9]+)?')

if [ -n "$pathParams" ]
then
	collection_id=$(echo "$pathParams" | cut -d / -f 2)
	p=$(echo "$pathParams" | cut -d / -f 3)
	if [ -n "$p" ]
	then
		page_num=$p
	fi
elif [ -n "$(echo $URL | grep 'idcollection=')" ]
then
	collection_id=$(echo "$URL" | tr '?&' '\n' | grep 'idcollection=' | cut -d = -f 2)
	p=$(echo "$URL" | tr '?&' '\n' | grep 'page=' | cut -d = -f 2)
	if [ -n "$p" ]
	then
		page_num=$p
	fi
else
	echo "error: non-valid url '$URL'" >&2
	usage
	exit 1
fi

echo "collection ID: $collection_id" >&2
echo "page number: $page_num" >&2

# <div id="map" data-img-url="/zoomify/?path=doc%2F2010%2F11%2F15%2F3700719/" data-doc-id="12949" data-api-url="https://en.geneanet.org/archives/registres/api/?idcollection=12949" data-navigation-mode="1" data-allow-fullscreen="" data-allow-paleo="1"></div>
html_data=$(curl -s "$URL" | grep "data-img-url" | tr ">" ' ' | tr ' ' '\n')
api_url=$(echo "$html_data" | strip_xml "data-api-url")
img_url=$(echo "$html_data" | strip_xml "data-img-url" | sed 's#%2F#/#g' | awk "{ print \"$BASE_URL\"\$0 }")

echo "API url: $api_url" >&2
echo "image url: $img_url" >&2

img_props=$(curl -s "$img_url"ImageProperties.xml | tr -d "<>/" | tr ' ' '\n')
img_width=$(echo "$img_props" | strip_xml "WIDTH")
img_height=$(echo "$img_props" | strip_xml "HEIGHT")
img_tilesize=$(echo "$img_props" | strip_xml "TILESIZE")

echo "image width: $img_width" >&2
echo "image height: $img_height" >&2
echo "image tilesize: $img_tilesize" >&2

dim_max=$(( $img_width > $img_height ? $img_width : $img_height ))

zoom_max=1
if [ "$dim_max" -gt 4096 ]
then
	zoom_max=5
elif [ "$dim_max" -gt 2048 ]
then
	zoom_max=4
elif [ "$dim_max" -gt 1024 ]
then
	zoom_max=3
elif [ "$dim_max" -gt 512 ]
then
	zoom_max=2
fi

echo "zoom max: $zoom_max"

TMPDIR=$(mktemp -d)
echo "temp directory is $TMPDIR" >&2

y=0
i=0
x=0
while [ $(( $y * $img_tilesize )) -lt $img_height ]
do
	x=0
	while [ $(( $x * $img_tilesize )) -lt $img_width ]
	do
		tile_url="$img_url""TileGroup0/$zoom_max-$x-$y.jpg"
		
		echo "$tile_url" >&2
		
		# assume it is "TileGroup0"
		curl -s -o $TMPDIR/"tmp_"$(printf "%05d" $i)".jpg" "$img_url""TileGroup0/$zoom_max-$x-$y.jpg"
		i=$(( $i + 1 ))
		x=$(( $x + 1 ))
	done
	y=$(( $y + 1 ))
done

montage $TMPDIR/tmp_*.jpg -mode concatenate -tile $(( $x ))x$(( $y )) "$collection_id-$page_num.jpg"
echo "wrote ./$collection_id-$page_num.jpg" >&2
rm -r $TMPDIR
