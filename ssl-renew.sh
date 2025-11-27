#!/bin/bash

# Script para renovar certificados SSL
# Uso: ./ssl-renew.sh
# Agregar a crontab: 0 3 * * * /ruta/al/proyecto/ssl-renew.sh

set -e

cd "$(dirname "$0")"

echo "Renovando certificados SSL..."
docker compose run --rm certbot renew

echo "Recargando Nginx..."
docker compose exec nginx nginx -s reload

echo "Certificados renovados exitosamente"
