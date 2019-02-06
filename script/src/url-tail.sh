#!/bin/bash

function show_help() {
	echo "Syntax: url-tail.sh [-b <starting tail offset in bytes>] [-u username] [-p password] <URL>"
	exit 0
}

# A POSIX variable
OPTIND=1 # Reset in case getopts has been used previously in the shell.

curl_username=""
curl_passwd=""
tail_off=0

while getopts "u:p:b:h" opt; do
		case "$opt" in
		h)
			show_help
			;;
		u) curl_username=$OPTARG
			;;
		p) curl_passwd=$OPTARG
			;;
		b)
			if [[ $tail_off == *[!0-9]* ]]; then
				echo "Tail offset must be a positive number"
				exit 1
			else
				tail_off=$OPTARG
			fi
			;;
		esac
done

shift $((OPTIND-1))


if [ $# -lt 1 ]; then
	show_help
fi

url=$1

if [ -n "$curl_username" ]; then
	if [ -z "$curl_passwd" ]; then
		read -s -p "Enter Password for user '$curl_username': " curl_passwd
		echo ""
	fi
fi

function check_authentication_required() {
	url=$1
	if [ -z "$curl_username" ]; then
		ret=`curl -s -I -X HEAD $url | grep "WWW-Authenticate:"`
	fi

	if [ -z "$ret" ]; then
		echo
	else
		return 1
	fi
}

function check_ranges_support() {
	url=$1
	if [ -n "$curl_username" ]; then
		ret=`curl -u $curl_username:$curl_passwd -s -I -X HEAD $url | grep -i "Accept-Ranges: bytes"`
	else
		ret=`curl -s -I -X HEAD $url | grep -i "Accept-Ranges: bytes"`
	fi

	# echo "${ret}"
	if [ -z "$ret" ]; then
		echo
	else
		return 1
	fi
}

function get_length() {

	url=$1
	if [ -n "$curl_username" ]; then
		ret=`curl -u $curl_username:$curl_passwd -s -I -X HEAD $url | awk '/(C|c)ontent-(L|l)ength:/ {print $2}'`
	else
		ret=`curl -s -I -X HEAD $url | awk '/(C|c)ontent-(L|l)ength:/ {print $2}'`
	fi
	echo $ret | sed 's/[^0-9]*//g'
}

function print_tail() {

	url=$1
	off=$2
	len=$3
	if [ -n "$curl_username" ]; then
		curl -u $curl_username:$curl_passwd --header "Range: bytes=$off-$len" -s $url
	else
		curl --header "Range: bytes=$off-$len" -s $url
	fi
}

check_authentication_required $url
authentication_required=$?

if [ $authentication_required -eq 1 ]; then
	echo "Authentication required by the server. Try with option -u and/or -p"
	exit 1
fi

check_ranges_support $url
ranges_support=$?

if [ $ranges_support -eq 0 ]; then
	echo "Ranges are nor supported by the server"
	exit 1
fi

len=`get_length $url`
off=$((len - tail_off))


until [ "$off" -gt "$len" ]; do
	len=`get_length $url`

	if [ "$off" -eq "$len" ]; then
		sleep 3
	else
		print_tail $url $off $len
	fi

	off=$len
done
