#!/bin/bash

CSV_SEPARATOR="|"
BASE_URL="http://www2.culture.gouv.fr"
FIELD_ID="Numéro d'inventaire"
FIELDS_OPT="Précision inscriptions,Anciennes appartenances,Commentaires,Historique,Date sujet représenté,Site complémentaire"

function usage
{
	echo "Get single notice from url :" >&2
	echo -e "\t"$(basename "$0")" <url> [field1,field2,...]" >&2
	echo "" >&2
	echo "Get notices from search result page :" >&2
	echo -e "\t<outputs html code> | "$(basename "$0")" - [field1,field2,...]" >&2
}

function extract_url
{
	grep 'A HREF="/Wave/image' | grep -Eo '/Wave/image[^"]+' | awk '{ print "'"$BASE_URL"'"$0 }' | grep "_p.jpg"
}

function extract_field
{
	grep -A 4 "$1" | tail -n 1 | sed -E 's/<N> *(.+)<\/N>.*/\1/' | sed -E 's/<[^>]+> *//g'
}

urls=""

if [ -z "$1" ]
then
	echo "error: missing argument" >&2
	usage
	exit 1
elif [ "$1" == '-' ]
then
	# read from stdin
	# hangs there if nothing is received
	urls=$(cat | grep -Eo '/public/mistral/[^"]+ACTION=RETROUVER&[^"]+' | awk '{ print "'"$BASE_URL"'"$0 }')
else
	urls="$1"
fi

urls_count=$(echo "$urls" | wc -l)
echo "$urls_count url(s)" >&2

counter=1

_fields="$FIELDS_OPT"
if [ -n "$2" ]
then
	_fields="$2"
fi

fields=$({
	echo "$FIELD_ID"
	echo "$_fields" | tr , $'\n'
})

echo -e "$fields\nIMAGE_URL" | paste -sd "$CSV_SEPARATOR" -

echo "$urls" | while read url
do
	echo "$counter/$urls_count" >&2
	
	html=$(curl -s "$url" | iconv -f ISO_8859-1 -t UTF-8 /dev/stdin)
	{
		echo "$fields" | while read f
		do
			echo $(echo "$html" | extract_field "$f")
		done
		echo "$html" | extract_url
	} | paste -sd "$CSV_SEPARATOR" -
	
	counter=$(( $counter + 1 ))
done
