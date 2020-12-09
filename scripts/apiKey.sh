#!/usr/bin/env bash

## creating an API key
keyRes=$(curl --user "${atlas_public_key}:${atlas_private_key}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "https://cloud.mongodb.com/api/atlas/v1.0/orgs/${org_id}/apiKeys?pretty=true" \
  --data '{
    "desc" : "Terraform API key",
    "roles": ["ORG_MEMBER"]
  }')

keyRes=$(curl --user "${atlas_public_key}:${atlas_private_key}" --digest \
     --header "Accept: application/json" \
     --header "Content-Type: application/json" \
     --request POST "https://cloud.mongodb.com/api/atlas/v1.0/groups/${project_id}/apiKeys?pretty=true" \
     --data '{
       "desc" : "Terraform API key",
       "roles": ["GROUP_OWNER"]
     }')

keyId=$(echo $keyRes | jq -r ".id")
private_key=$(echo $keyRes | jq -r ".privateKey")
public_key=$(echo $keyRes | jq -r ".publicKey")

## whitelist IPs for API key
curl --user "${atlas_public_key}:${atlas_private_key}" --digest \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--include \
--request POST "https://cloud.mongodb.com/api/public/v1.0/orgs/${org_id}/apiKeys/$keyId/whitelist?pretty=true" \
--data '
  [{
      "ipAddress" : "${local_ip}"
   }]'

## granting api key project owner privilege on a project
curl --user "${atlas_public_key}:${atlas_private_key}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --include \
  --request PATCH "https://cloud.mongodb.com/api/atlas/v1.0/groups/${project_id}/apiKeys/$keyId?pretty=true" \
  --data '{
    "roles": [ "GROUP_OWNER" ]
  }'