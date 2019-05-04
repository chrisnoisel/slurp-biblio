#!/bin/bash

HEADERS="Titre principal,Autres titres,Éditeur commercial,Description physique,Notes générales,Autres notes,Sujets,Autres langues,Thème"
BASE_URL='http://artsdecoratifs.e-sezhame.fr'
CSV_SEPARATOR=$'\t'

#######

function usage
{
	echo -e "usage:"
	echo -e "\t"$(basename "$0")" <search url>"
	echo -e "\t"$(basename "$0")" <document url>"
}

if [ -z "$1" ]
then
	echo "error: missing argument." >&2
	usage >&2
	exit 1
fi

HEADERS_FULL="$HEADERS,URL,URL_IMAGE"

function get_headers_csv
{
	echo "$HEADERS_FULL" | tr , "$CSV_SEPARATOR"
}

####### document functions

function separate_fields
{
	sed -E 's#</th>#'$'\t''#'
}

function separate_lines
{
	sed -E 's#</div>|<.?br.?>|</li>#|#g'
}

function strip_html_tags
{
	sed -E 's/<[^>]+>//g'
}

function final_clean
{
	sed -E 's/\|\|/|/g' | sed -E 's/\|$//'
}

function read_data
{
	grep "^$1"$'\t' | cut -d $'\t' -f 2- | paste -sd '|' -
}

function get_page_csv
{
	idgabi=$(curl -gsL "$1" | grep -Eo 'DKAJAX.get_documents_details\("[0-9_]+"\)' | grep -Eo '[0-9]+_[0-9]+')
	dirtyxml=$(curl -gsL "http://artsdecoratifs.e-sezhame.fr/search.php?action=ajax&method=get_documents_details&champsgabi=undefined&itype=Gabi&idgabi=$idgabi")

	url_image=$(echo "$dirtyxml" | grep -Eo 'img_url : "[^"]+' | tr -d '"' | cut -d ':' -f 2- | sed 's/^ //')
	url_doc="http://artsdecoratifs.e-sezhame.fr/id_"$(echo $idgabi | cut -d '_' -f 2)".html"
	data=$({
		echo "$dirtyxml" | tr -d '\n\r\t' | grep -Eo '<tab>.+</tab>' | gawk -v RS="<tr>" 'NR > 1 { print $0 }' | sed -E 's/<script>[^<]+<\/script>//g' | sed 's/<\/tr>.*$//' | separate_fields | separate_lines | strip_html_tags | final_clean
		echo -e "URL"$'\t'"$url_doc"
		echo -e "URL_IMAGE"$'\t'"$url_image"
	})

	echo "$HEADERS_FULL" | tr , '\n' | while read header
	do
		echo "$data" | read_data "$header"
	done | paste -sd "$CSV_SEPARATOR" -
}

####### search functions

function enhance_search
{
	endpoint=$(echo "$url" | cut -d '?' -f 1)
	params=$(echo "$url" | cut -d '?' -f 2- | tr '&' '\n' | grep -Ev -e '^page=' -e '^so_default_itemsperpage=')
	echo "$endpoint"'?'$(echo "$params" | paste -sd '&' -)"&so_default_itemsperpage=30"
}

function get_urls_from_searchpage
{
	curl -gsL "$1" | grep 'class="url"' | grep -Eo 'search.php[^<]+' | gawk '{ print "'"$BASE_URL"'/"$0 }'
}

function run_search
{
	html=$(curl -gsL "$1")
	max_page=$(echo "$html" | tr -d '\n\r\t' | gawk -v RS='pagination_top[^>]+> *' 'NR == 2' | gawk -v RS='</div>' 'NR == 1' | sed 's#</a>#\'$'\n''#g' | grep -Ev "^ *$" | grep -v Suivant | tail -n 1 | grep -Eo '(&|\?|&amp;)page=[0-9]+' | cut -d = -f 2)
	if [ -z "$max_page" ]
	then
		max_page=1
	fi
	page=1
	
	while [[ $page -le $max_page ]]
	do
		echo "$page/$max_page ..." >&2
		get_urls_from_searchpage "$1&page="$page | while read url
		do
			get_page_csv "$url"
		done
		page=$(( $page + 1 ))
	done
}

####### main

for url in $@
do
	get_headers_csv
	if [ -n ""$(echo "$url" | grep 'lookfor=') ]
	then
		run_search $(enhance_search "$url")
	else
		get_page_csv "$url"
	fi
done
