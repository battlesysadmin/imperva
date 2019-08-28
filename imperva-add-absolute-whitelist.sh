#!/bin/bash
# Maintainer: Lois Garcia
# Prerequisites: API credentials, Site ID
# Optional: jq installed locally to parse output

# this script will add IPs to the absolute, insecure whitelist for a specified site

echo "WARNING: Any IPs entered now will replace, not be appended to, the existing absolute whitelist."

echo -n "Enter API ID: "
read api_id

echo -n "Enter API Key: "
read api_key

echo -n "Enter Site ID: "
read site_id

echo -n "Enter comma-separated (no spaces) list of IPs to allow: "
read ips

echo "About to start work on..."
curl -k -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id" https://my.incapsula.com/api/prov/v1/sites/status | jq -r '.domain'

read -p "Should we proceed? (y/N) " choice
case "$choice" in
   y|Y ) ;;
   n|N ) echo "OK. Exiting script."; exit;;
   * ) echo "Invalid answer. Exiting script."; exit;;
esac

curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.acl.whitelisted_ips&ips=$ips" https://my.incapsula.com/api/prov/v1/sites/configure/whitelists | jq '.res_message'
