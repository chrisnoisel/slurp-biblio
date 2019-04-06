#!/bin/bash

# https://www.interencheres.com/meubles-objets-art/collections-collectionneurs-248498/lot-19733096.html

function curl_simulate_firefox
{
	curl -s -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' -H 'Cache-Control: max-age=0' -H 'TE: Trailers' "$1"
}

urls=$(curl_simulate_firefox "$1" | grep data-originalsrc | grep -v full-fit-in | tr -d '"' | cut -d '=' -f 2- | sed -E 's#^//#https://#')

echo "$urls" >&2

counter=1
echo "$urls" | while read url
do
	#curl "$url" | convert - jpg:"$counter".jpg
	curl -H 'Accept: image/webp,*/*' -O "$url"
	counter=$(( $counter + 1 ))
done
