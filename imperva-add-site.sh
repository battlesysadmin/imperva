#!/bin/bash
# Maintainer: Lois Garcia
# Prerequisites: Imperva API credentials, Site ID
# Optional: jq installed locally to parse JSON output
# This script will add a site to Incapsula with basic settings. Adjust these to suit your organization. DNS changes will need to be made to complete site addition to Incapsula. Without DNS, traffic to the site will not route through Incapsula.

# your API key may default to an account ID, so this might not be necessary
echo -n "Enter account ID."
read account_id

# FQDN for site you are adding
echo -n "Enter full site name to add, for example, 'www.example.com': "
read domain

echo -n "Enter API ID: "
read api_id

echo -n "Enter API Key: "
read api_key

echo -n "Enter IPs to be blacklisted/blocked (comma separated list): "
read blacklist_ips

echo -n "Enter IPs to be whitelisted as IP block exceptions (comma separated list): "
read ip_exceptions

echo -n "Enter IPs to be completely whitelisted, bypassing all logging and alerting (comma separated list): "
read whitelist_ips


# comment out user input fields above and
# hardcode variables below for personal use
# do not check in to Git with hardcoded variables

#account_id=""
#api_id=""
#api_key=""

# IPS to be blacklisted/blocked
#blacklist_ips="1.1.1.1"

# IPS to be whitelisted as IP block exceptions
#ip_exceptions="2.2.2.2"

# IPS to be completely whitelisted, bypassing all logging and alerting
#whitelist_ips="3.3.3.3"

# Add the new website
echo " "
echo "Adding $domain to account $account_id..."
curl -k -s --data "api_id=$api_id&api_key=$api_key&account_id=$account_id&domain=$domain&site_ip=$origin" https://my.incapsula.com/api/prov/v1/sites/add | jq '.' > site_response.json

# Check if site was added successfully
res_message=$(cat site_response.json | jq -r '.res_message')
if [ $res_message == "OK" ]
then
 echo "Site added successfully"
else
 echo "Site was not added successfully. Please review the site_response.json file for more details."
 exit
fi

# Extract information from Add Site API response
site_id=$(cat site_response.json | jq '.site_id')
echo "Site id: $site_id"

echo "Configuring $domain..."

# add IPs to completely whitelist (currently, only Tenable scanning origin IPs)
echo " "
echo "Adding IPs to absolute whitelist..."
curl -k -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.acl.whitelisted_ips&ips=$whitelist_ips" https://my.incapsula.com/api/prov/v1/sites/configure/acl | jq '.res_message'

# add IPs as exceptions to the IP block setting
echo " "
echo "Adding IPs to IP block exceptions..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.acl.blacklisted_ips&ips=$ip_exceptions" https://my.incapsula.com/api/prov/v1/sites/configure/whitelists | jq '.res_message'

echo " "
echo "Adding IPs to blacklist..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.acl.blacklisted_ips&ips=$blacklist_ips" https://my.incapsula.com/api/prov/v1/sites/configure/acl | jq '.res_message'

# set site log level
echo " "
echo "Setting Site Log Level..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&log_level=full" https://my.incapsula.com/api/prov/v1/sites/setlog  | jq '.res_message'

# set WAF rule actions

# do not block "bad bots"
echo " "
echo "Setting allow Bad Bots to accommodate common tools..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.threats.bot_access_control&block_bad_bots=false" https://my.incapsula.com/api/prov/v1/sites/configure/security | jq '.res_message'

# block SQL injection attempts
echo " "
echo "Blocking SQL Injection attempts..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.threats.sql_injection&security_rule_action=api.threats.action.block_user" https://my.incapsula.com/api/prov/v1/sites/configure/security | jq '.res_message'

# block cross-site scripting
echo " "
echo "Blocking XSS attempts..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.threats.cross_site_scripting&security_rule_action=api.threats.action.block_user" https://my.incapsula.com/api/prov/v1/sites/configure/security | jq '.res_message'

# block backdoor attempts
echo " "
echo "Setting backdoor auto-quarantine..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.threats.backdoor&security_rule_action=api.threats.action.quarantine_url" https://my.incapsula.com/api/prov/v1/sites/configure/security | jq '.res_message'

# block remote file inclusion
echo " "
echo "Blocking remote file inclusion..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.threats.remote_file_inclusion&security_rule_action=api.threats.action.block_user" https://my.incapsula.com/api/prov/v1/sites/configure/security | jq '.res_message'

# block illegal resource access
echo " "
echo "Blocking illegal resource access..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.threats.illegal_resource_access&security_rule_action=api.threats.action.block_user" https://my.incapsula.com/api/prov/v1/sites/configure/security | jq '.res_message'

# Setting DDoS protections to auto and default thresholds
echo " "
echo "Enabling automatic DDoS protection..."
curl -s --data "api_id=$api_id&api_key=$api_key&site_id=$site_id&rule_id=api.threats.ddos&activation_mode=api.threats.ddos.activation_mode.auto" https://my.incapsula.com/api/prov/v1/sites/configure/security | jq '.res_message'

# adding IncapRule to log all traffic
echo " "
echo "Adding all traffic rule..."
curl -X POST -d api_id=$api_id -d api_key=$api_key -d site_id=$site_id -d name=all_traffic -d action=RULE_ACTION_ALERT -d filter='URL contains "/"' https://my.incapsula.com/api/prov/v1/sites/incapRules/add

# Cleanup
[ -e site_response.json ] && rm site_response.json

echo " "
echo "Done."
