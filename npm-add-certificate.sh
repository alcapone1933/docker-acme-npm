#!/bin/bash

function usage {
    echo "Usage: npm-add-certificate -n <certificate_name> -c <path_to_certificate> -k <path_to_certificate_key>"
    exit 0
}

if [ $# -eq 0 ]
  then
    usage
    exit 1
fi

while getopts ":hn:c:k:" opt
do
    case "${opt}" in
        n) cert_name=${OPTARG}
           ;;
        c) cert=${OPTARG}
           ;;
        k) cert_key=${OPTARG}
           ;;
        h) usage
           ;;
        :) echo "$0: Must supply an argument to -$OPTARG." >&2
           usage
           exit 2
           ;;
        \?) echo "Invalid option: -${OPTARG}."
           usage
           exit 3
           ;;
        *) usage
           exit 4
           ;;
    esac
done


# API="http://<nginx-proxy-manager-ip>:81/api"
# IDENTITY='<your-nginx-proxy-manager-username>'
# SECRET='<your-nginx-proxy-manager-password>'
TOKEN=""
TOKEN_EXP_DATE=""

function login {
        credentials=$(jq -n --arg id "$IDENTITY" --arg secret "$SECRET" '{ identity: $id, secret: $secret }')
        response=$(curl -s -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' -d "${credentials}" "${API}/tokens")
        echo ${response} | jq -r --exit-status '.erro' &>/dev/null
        [[ $? -eq 0 ]] && echo "Error: login failed." && exit
        TOKEN="Bearer $(echo $response | jq -r '.token')"
        TOKEN_EXP_DATE=$(echo $response | jq -r '.expires')
}

login

certs=$(curl -s -H 'Accept: application/json' -H "Authorization: ${TOKEN}" "${API}/nginx/certificates?expand=owner")
old_cert_id=$(echo $certs | jq -r '.[] | select(.nice_name=="'"${cert_name}"'") | .id')
[[ $old_cert_id == *$'\n'* ]] && echo "Warning: multiple certs with name \"${cert_name}\" found! Aborting." && exit 5

hosts=$(curl -s -H 'Accept: application/json' -H "Authorization: ${TOKEN}" "${API}/nginx/proxy-hosts")

if [[ ${old_cert_id} != "" ]]
then
        old_cert_hosts=$(echo $hosts | jq -r '[.[] | select(.certificate_id=='"${old_cert_id}"') | .id] | @csv')
        IFS=', ' read -r -a old_cert_hosts <<< "$old_cert_hosts"

        echo "Removing old certificate.."
        delete_result=$(curl -s -X DELETE -H "Authorization: ${TOKEN}" "${API}/nginx/certificates/${old_cert_id}")
        [[ ${delete_result} != "true" ]] && echo "Unable to delete existing certificate." && exit;
fi

echo "Validating new certificate..."
validation_result=$(curl -s -X POST -H "Authorization: ${TOKEN}" -F "certificate=@${cert}" -F "certificate_key=@${cert_key}" "${API}/nginx/certificates/validate")
[[ ${validation_result} == "" ]] && echo "Unable to validate new certificate." && exit;

validation_error=$(echo ${validation_result} | jq -r --exit-status '.error')
[[ $? -eq 0 ]] && echo ${validation_error} && exit

echo ${validation_result} | jq -r --exit-status '.certificate' &>/dev/null
[[ $? -ne 0 ]] && echo "Error: missing certificate." && exit

echo ${validation_result} | jq -r --exit-status '.certificate_key' &>/dev/null
[[ $? -ne 0 ]] && echo "Error: missing certificate key." && exit

echo "Uploading new certificate.."
new_cert=$(curl -s -X POST -H "Authorization: ${TOKEN}" -F "nice_name=${cert_name}" -F 'provider=other' "${API}/nginx/certificates")
new_cert_id=$(echo ${new_cert} | jq -r .id)
curl -s -X POST -H "Authorization: ${TOKEN}" -F "certificate=@${cert}" -F "certificate_key=@${cert_key}" "${API}/nginx/certificates/${new_cert_id}/upload" &>/dev/null


echo "Updating hosts..."
for hid in "${old_cert_hosts[@]}"
do
        host_keys='"domain_names", "forward_scheme", "forward_host", "forward_port", "certificate_id", "ssl_forced", "hsts_enabled", "hsts_subdomains", "http2_support", "block_exploits", "caching_enabled", "allow_websocket_upgrade", "access_list_id", "advanced_config", "enabled", "meta", "locations"'
        old_host=$(curl -s -H 'Accept: application/json' -H "Authorization: ${TOKEN}" "${API}/nginx/proxy-hosts/${hid}")
        # https://stackoverflow.com/a/43354218
        modified_host=$( echo $old_host | jq '. | with_entries(select(.key == ('"${host_keys}"'))) | .certificate_id = '"${new_cert_id}")

        echo "Updating host #${hid}..."
        curl -s -X PUT -H "Authorization: ${TOKEN}" -H 'Content-Type: application/json' -d "${modified_host}" "${API}/nginx/proxy-hosts/${hid}" &>/dev/null
done

echo "Done."
