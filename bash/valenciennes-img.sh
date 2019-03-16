#!/bin/bash

BASE_URL="https://patrimoine-numerique.ville-valenciennes.fr"

function usage
{
	echo "usage:" >&2
	echo -e "\t$0 <url>" >&2
}

if [ ! -n $(which curl) ]
then
	echo "curl is missing." >&2
	exit 1
fi

if [ ! -n "$1" ]
then
	usage
	exit 1
fi

curl -s "$1" | grep hiResimage | tr , '\n' | grep "hiResimage" | cut -d : -f 2 | tr -d '"' | awk '{ print "'$BASE_URL'"$0 }'

