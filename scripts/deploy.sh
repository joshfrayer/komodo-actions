#!/bin/bash
set -euo pipefail
echo "Deploying stack: ${STACK_NAME} with image tag: ${BUILD_TAG}"
RESPONSE=$(curl -sSf -X POST "${KOMODO_HOST}/execute/DeployStack" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $KOMODO_API_KEY" \
    -H "x-api-secret: $KOMODO_API_SECRET" \
    -d "$(jq -n --arg stack "$STACK_NAME" --arg build_tag "$BUILD_TAG" \
        '{stack: $stack, build_tag: $build_tag}')")
UPDATE_ID=$(echo "$RESPONSE" | jq -r '
    ._id as $id |
    if ($id | type) == "object" then
        $id["$oid"] // .id // empty
    else
        $id // .id // empty
    end
')
if [ -z "$UPDATE_ID" ] || [ "$UPDATE_ID" == "null" ]; then
    echo "Failed to get update ID from response: $RESPONSE"
    exit 1
fi
echo "Deployment initiated with update ID: $UPDATE_ID"
TIMEOUT=300
ELAPSED=0
INTERVAL=5
while [ $ELAPSED -lt $TIMEOUT ]; do
    UPDATE_STATE=$(curl -sSf -X POST "${KOMODO_HOST}/read/GetUpdate" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $KOMODO_API_KEY" \
        -H "x-api-secret: $KOMODO_API_SECRET" \
        -d "$(jq -n --arg id "$UPDATE_ID" '{id: $id}')")
    STATUS=$(echo "$UPDATE_STATE" | jq -r '.status // empty')
    SUCCESS=$(echo "$UPDATE_STATE" | jq -r '.success // empty')
    echo "[+${ELAPSED}s] Status: ${STATUS:-Pending}"
    if [ "$STATUS" == "Complete" ] || [ "$STATUS" == "Finished" ]; then
        if [ "$SUCCESS" == "true" ]; then
            echo "Deployment completed successfully!"
            exit 0
        else
            echo "Deployment failed! Details:"
            echo "$UPDATE_STATE" | jq -r '.logs[]? // empty'
            exit 1
        fi
    elif [ "$STATUS" == "Failed" ]; then
        echo "Deployment marked as Failed! Details:"
        echo "$UPDATE_STATE" | jq -r '.logs[]? // empty'
        exit 1
    fi
    sleep "$INTERVAL"
    ELAPSED=$((ELAPSED + INTERVAL))
done
echo "Deployment timed out after ${TIMEOUT}s waiting for Komodo."
exit 1