#!/bin/bash

# Get environment variables
PORT_CLIENT_ID="$PORT_CLIENT_ID"
PORT_CLIENT_SECRET="$PORT_CLIENT_SECRET"
DATADOG_API_KEY="$DATADOG_API_KEY"
DATADOG_APPLICATION_KEY="$DATADOG_APPLICATION_KEY"
DATADOG_API_URL="$DATADOG_API_URL"
DATADOG_ENVIRONMENT_ID="$DATADOG_ENVIRONMENT_ID"
PORT_API_URL="https://api.getport.io/v1"
BLUEPRINT_ID="service"

# Get Port Access Token
credentials="{\"clientId\": \"$PORT_CLIENT_ID\", \"clientSecret\": \"$PORT_CLIENT_SECRET\"}"
token_response=$(curl -X POST -H "Content-Type: application/json" -d "$credentials" "$PORT_API_URL/auth/access_token")
access_token=$(echo "$token_response" | jq -r '.accessToken')

# Create entity in Port
add_entity_to_port() {
    entity_object="$1"
    response=$(curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -d "$entity_object" "$PORT_API_URL/blueprints/$BLUEPRINT_ID/entities?upsert=true&merge=true&create_missing_related_entities=true")
    echo "$response"
}

# Retrieve service dependencies from Datadog using REST API
retrieve_service_dependencies() {
    env="$1"
    headers="-H 'DD-API-KEY: $DATADOG_API_KEY' -H 'DD-APPLICATION-KEY: $DATADOG_APPLICATION_KEY' -H 'Accept: application/json'"
    services_response=$(curl -H "DD-API-KEY: $DATADOG_API_KEY" -H "DD-APPLICATION-KEY: $DATADOG_APPLICATION_KEY" -H "Accept: application/json" "$DATADOG_API_URL/api/v1/service_dependencies?env=$env")
    service_dependencies=$(echo "$services_response" | jq '.')
    echo "$service_dependencies"

    for service in $(echo "$service_dependencies" | jq -r 'keys[]'); do
        calls=$(echo "$service_dependencies" | jq -r ".[\"$service\"] | select(.calls) | .calls")
        if [[ "$calls" != "null" ]]; then
            entity="{\"identifier\": \"$service\", \"title\": \"$service\", \"properties\": {}, \"relations\": {\"service\": $calls}}"
            add_entity_to_port "$entity"
        fi
    done
}

retrieve_service_dependencies "$DATADOG_ENVIRONMENT_ID"