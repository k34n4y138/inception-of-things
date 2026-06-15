#!/bin/bash



ADMIN_USERNAME="zmoumen"
ADMIN_EMAIL="zmoumen@student.1337.ma"
ADMIN_PASSWORD=$(openssl rand -base64 8)

kubectl create secret generic gitea-admin \
  --from-literal=username="$ADMIN_USERNAME" \
  --from-literal=email="$ADMIN_EMAIL" \
  --from-literal=password="$ADMIN_PASSWORD" \
  -n gitea

echo "gitea-admin secret created with username: $ADMIN_USERNAME and password: $ADMIN_PASSWORD"
