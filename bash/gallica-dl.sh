#!/bin/bash

# reference : http://johannadaniel.fr/isidoreganesh/2018/03/comment-telecharger-des-images-en-haute-definition-sur-gallica/

function usage
{
	echo -e "usage :" >&2
	echo -e $'\t'$(basename "$0")" <url>" >&2
	echo -e $'\t'$(basename "$0")" <ark:/xxx/yyy>[/fzzz]" >&2
}

ark=""

if [ -z "$1" ]
then
	echo "error: missing parameter." >&2
	usage
	exit 1
fi

if [[ "$1" == "http"* ]]
then
	ark=$(echo "$1" | grep -Eo 'ark:/[a-zA-Z0-9]+/[a-zA-Z0-9]+(/f[0-9])?')
elif [[ "$1" == "ark:/"* ]]
then
	ark="$1"
else
	echo "error: unknown parameter '$1'" >&2
	usage
	exit 1
fi

ark_full=$(echo "$ark" | sed -E 's#ark:/[^/]+/[^/]+$#\0/f1#')
iiif_url="https://gallica.bnf.fr/iiif/$ark_full/full/full/0/native.jpg"

echo "$iiif_url" >&2
curl -L -o $(echo "$ark_full" | sed -E 's#ark:/([^/]+)/([^/]+)/f([^/]+)$#\1-\2-\3#' )".jpg" "$iiif_url"
