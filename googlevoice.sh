#!/bin/sh

UrlEncode()
{
replacements='{
 s/%/%25/g
 s/ /%20/g
 s/ /%09/g
 s/!/%21/g
 s/"/%22/g
 s/#/%23/g
 s/\$/%24/g
 s/\&/%26/g
 s/'\''/%27/g
 s/(/%28/g
 s/)/%29/g
 s/\*/%2a/g
 s/+/%2b/g
 s/,/%2c/g
 s/-/%2d/g
 s/\./%2e/g
 s/\//%2f/g
 s/:/%3a/g
 s/;/%3b/g
 s//%3e/g
 s/?/%3f/g
 s/@/%40/g
 s/\[/%5b/g
 s/\\/%5c/g
 s/\]/%5d/g
 s/\^/%5e/g
 s/_/%5f/g
 s/`/%60/g
 s/{/%7b/g
 s/|/%7c/g
 s/}/%7d/g
 s/~/%7e/g
 s/	/%09/g
}'
echo $1 | sed "${replacements}"
}

PhoneOnly()
{
echo $1 | sed 's/[^0-9\+]//g'
}


if [ $# != 4 ]; then
	echo "Usage: $0 login password call_number forwarding_number"
	exit 1
fi


user=$(UrlEncode $1)
password=$(UrlEncode $2)
number=$(UrlEncode $(PhoneOnly $3))
forward=$(UrlEncode $(PhoneOnly $4))

cookie_file=`mktemp`
touch ${cookie_file}


WGET="wget -q -O - --load-cookies=${cookie_file} --save-cookies=${cookie_file} --keep-session-cookies"
SED="sed -r -n"


# Logging in requires a GALX code.  First get this code
# TODO: Make expression less brittle wrt attribute ordering
galx_exp='name=["]GALX["]\s+value=["]([^"]*)["]'
login_url='https://www.google.com/accounts/ServiceLoginAuth?service=grandcentral'

galx=`${WGET} ${login_url} | ${SED} "N;s/^.*${galx_exp}.*$/\1/p"`
if [ -z ${galx} ]; then
	echo "Error starting login" 1>&2
	rm -f ${cookie_file}
	exit 1
fi


# Log in with the provided credentials
data="Email=${user}&Passwd=${password}&GALX=${galx}&rmShown=1&service=grandcentral"
${WGET} --post-data=${data} ${login_url} > /dev/null


# All operations require an RNR token.  Get the token .
# TODO: Make expression less brittle wrt attribute ordering
rnr_exp='name=["]_rnr_se["]\s+type=["]hidden["]\s+value=["]([^"]*)["]'
main_url='https://www.google.com/voice'

rnr=`${WGET} ${main_url} | ${SED} "N;s/^.*${rnr_exp}.*$/\1/p"`
if [ -z ${rnr} ]; then
	echo "Error logging in" 1>&2
	rm -f ${cookie_file}
	exit 1
fi


# Place the call
call_url='https://www.google.com/voice/call/connect'
status_exp='"?code"?\s*:\s*([^},])'

data="outgoingNumber=${number}&forwardingNumber=${forward}&_rnr_se=${rnr}&phoneType=2"
status=`${WGET} --post-data=${data} ${call_url} | ${SED} "s/^.*${status_exp}.*$/\1/p"`
if [ -z ${status} ] || [ ${status} != "0" ]; then
	echo "Error placing call: code ${status}" 1>&2
	rm -f ${cookie_file}
	exit 1
fi


# Logout
logout_url='https://www.google.com/voice/account/signout'

${WGET} ${logout_url} > /dev/null
rm -f ${cookie_file}
exit 0
