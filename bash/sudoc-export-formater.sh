#!/bin/bash

## infos
# WS multiwhere
# https://web.archive.org/web/20170704152441/http://documentation.abes.fr/sudoc/manuels/administration/aidewebservices/multiwhere.html
#
# WS sudoc
# https://web.archive.org/web/20170627124846/http://documentation.abes.fr/sudoc/manuels/administration/aidewebservices/index.html

TERM_NEW_ARTWORK="Identifiant pérenne de la notice"
CSV_SEPARATOR1=$'\t'
CSV_SEPARATOR2='|'

function usage
{
	echo -e "usage:\n\t"$(basename "$0")" <sudoc_search_export_file>"
}

function sudoc_simple_request
{
	curl -sL "$1" \
	-c "$2" \
	-H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' \
	--compressed \
	-H $'Cookie: DB="2.1"; COOKIE="U10178,Klecteurweb,I250,B341720009+,SY,NLECTEUR+WEBOPC,D2.1,E5c409e3d-10,A,H,R90.24.238.88,FY"; cookie-banner-accept=1'
}

function sudoc_where_to_find
{
	xml=$(curl -sL -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' -b "$1" "http://www.sudoc.abes.fr//DB=2.1/SET=1/TTL=1/PRS=HOL/SHW?FRST=1&HLIB=$2#$2")
	
	terms="Bibliothèque,Note sur l'exemplaire,Cote"
	echo "$terms" | tr , $'\n' | while read term
	do
		# Yeah, shoulda use an XML parser, I know.
		echo "$term|"$(echo "$xml" | grep "<psi:text>$term" | tr '>' $'\n' | grep -E ".</psi:text" | tail -n+2 | cut -d '<' -f 1 | sed 's/&#34;/"/g' | paste -sd "$CSV_SEPARATOR2" -)
	done
}

function sudoc_infos_from_url
{
	ppn=$(echo "$1" | grep -Eo "sudoc.fr/.+" | cut -d '/' -f 2)
	
	# TODO : use https://www.sudoc.fr/20338489X.xml
	#				http://documentation.abes.fr/sudoc/formats/unmb/zones/316.htm
	#				http://www.bnf.fr/documents/UNIMARC(B)_conversion.pdf
	#			 https://www.sudoc.fr/20338489X.html

	tmp_cookie=$(mktemp)

	sudoc_simple_request "http://www.sudoc.fr/$ppn" "$tmp_cookie" >> /dev/null
	
	# TODO : use https://www.sudoc.fr/services/multiwhere/20338489X
	rcr=$(curl -sL "https://www.sudoc.fr/export/q=ppn&v=$ppn" | tr '<' $'\n' | grep '209A' -A 1 | tail -n 1 | cut -d '>' -f 2)
	
	sudoc_where_to_find "$tmp_cookie" "$rcr"

	rm "$tmp_cookie"
}

if [ -z "$1" ]
then
	echo "error: missing argument" >&2
	usage
	exit 1
fi

data=$({
	sed -E 's/^ +//' "$1"
	echo " "
})
terms=$(echo "$data" | grep ' : ' | cut -d ':' -f 1 | sed 's/ $//' | sort -u)
terms_more_data="Bibliothèque
Note sur l'exemplaire
Cote"

echo "(debug) termes :" >&2
echo "$terms" >&2
echo "$terms_more_data" >&2
echo "-------" >&2


regexp=$(echo "$terms" | awk '{ print $0" : " }')
buf=""
empty_counter=0
last_field=""
more_data=""
echo -e "$terms"$'\n'"$terms_more_data" | paste -sd "$CSV_SEPARATOR1" -
echo "$data" | while read line_raw
do
	line=$(echo "$line_raw" | tr -d $'\r')
	if [ -z "$line" ]
	then
		empty_counter=$(( $empty_counter + 1 ))
		
		if [ $empty_counter -ge 2 ]
		then
			# end of artwork info -> display
			
			{
				echo "$terms" | while read term
				do
					echo $(echo "$buf" | grep "$term" | cut -d = -f 2- | paste -sd "$CSV_SEPARATOR2" -)""
				done
				
				echo "$terms_more_data" | while read term
				do
					echo $(echo "$more_data" | grep "$term" | cut -d '|' -f 2- | paste -sd "$CSV_SEPARATOR2" -)""
				done
			} | paste -sd "$CSV_SEPARATOR1" -
			
			buf=""
			more_data=""
			empty_counter=0
		fi
	else
		empty_counter=0
		match=$(echo "$line" | grep -Fo "$regexp")
		if [ -n "$match" ]
		then
			# has field
			formated_line=$(echo "$line" | sed 's/ : /=/')
			last_field=$(echo "$formated_line" | cut -d = -f 1)
			buf="$buf$formated_line"$'\n'
			
			if [ "$match" == "$TERM_NEW_ARTWORK : " ]
			then
				# get url
				more_data=$(sudoc_infos_from_url $(echo "$formated_line" | cut -d = -f 2))
			fi
		else
			# no field, repeat last one
			buf="$buf$last_field=$line"$'\n'
		fi
	fi
	
done
