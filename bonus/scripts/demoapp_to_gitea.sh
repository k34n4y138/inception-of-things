#!/bin/bash

set -euo pipefail

GITEA_INCLUSTER_CLI=(kubectl exec -n gitea deploy/gitea -- gitea)
GITEA_BASE_URL="http://localhost:8068"

TOKEN_NAME="$(date +"%Y%m%d-%H%M%S")"
GITEA_ACCESS_TOKEN="$(${GITEA_INCLUSTER_CLI[@]} admin user generate-access-token -u zmoumen --token-name "$TOKEN_NAME" 2> /dev/null | awk -F': ' '/^Access token was successfully created:/ {print $2; exit}')" 

REPO_NAME="wills"
REPO_URL="http://zmoumen:${GITEA_ACCESS_TOKEN}@localhost:8068/zmoumen/${REPO_NAME}.git"


cd ./manifests/application

echo "Pushing content of {$(pwd)} to Gitea repository ${REPO_NAME}..."

git init -b master || true

git add .

git commit -m "Initial commit"

if ! curl -fsS -H "Authorization: token ${GITEA_ACCESS_TOKEN}" "${GITEA_BASE_URL}/api/v1/user/repos" | grep -q "\"name\":\"${REPO_NAME}\""; then
	curl -fsS -X POST \
		-H "Authorization: token ${GITEA_ACCESS_TOKEN}" \
		-H "Content-Type: application/json" \
		-d "{\"name\":\"${REPO_NAME}\"}" \
		"${GITEA_BASE_URL}/api/v1/user/repos" >/dev/null
        echo "Repository ${REPO_NAME} created successfully."
else
    echo "Repository ${REPO_NAME} already exists."
fi

git remote add origin "$REPO_URL"

git push -u origin master
