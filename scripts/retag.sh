#!/bin/bash
set -euo pipefail
RESPONSE=$(curl -sSf -X POST "${KOMODO_HOST}/read/GetStack" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${KOMODO_API_KEY}" \
    -H "x-api-secret: ${KOMODO_API_SECRET}" \
    -d "$(jq -n --arg stack "${STACK_NAME}" '{stack: $stack}')")
UPDATED_PAYLOAD=$(echo "${RESPONSE}" | jq \
    --arg host "${REGISTRY_HOST}" \
    --arg images "${REGISTRY_IMAGES}" \
    --arg tag "${BUILD_TAG}" \
    --arg id "${STACK_NAME}" \
    '
        def update_image_tag($img; $t):
            ($img | gsub("\\."; "\\.") | gsub("/"; "\\/")) as $escaped |
            sub("(?m)^(?<indent>[ \\t]*image:[ \\t]*[\"'\''\"]?)" + $escaped + "(?::[^\"'\''\\s]+)?(?<quote>[\"'\''\"]?)";
                "\(.indent)" + $img + ":" + $t + "\(.quote)");

        ([$images | splits("[ ,]+") | select(length > 0)]) as $img_list |

        (reduce $img_list[] as $img (
            .config.file_contents;
            update_image_tag($host + "/" + $img; $tag)
        )) as $new_compose |

        {
            "id": $id,
            "config": (.config + { "file_contents": $new_compose })
        }
    ')
curl -s -f -X POST "${KOMODO_HOST}/write/UpdateStack" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${KOMODO_API_KEY}" \
    -H "x-api-secret: ${KOMODO_API_SECRET}" \
    -d "${UPDATED_PAYLOAD}" | jq .