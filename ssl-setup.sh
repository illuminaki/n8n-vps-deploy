#!/bin/bash

# Script para configurar SSL con Let's Encrypt
# Uso: ./ssl-setup.sh

set -e

echo "=========================================="
echo "  Configuración SSL para n8n con Certbot"
echo "=========================================="
echo ""

# Verificar que existe el archivo .env
if [ ! -f .env ]; then
    echo "Error: No se encuentra el archivo .env"
    echo "Copia .env.example a .env y configúralo primero"
    exit 1
fi

# Cargar variables de entorno
source .env

# Verificar variables requeridas
if [ -z "$DOMAIN_NAME" ] || [ -z "$SSL_EMAIL" ]; then
    echo "Error: DOMAIN_NAME y SSL_EMAIL deben estar configurados en .env"
    exit 1
fi

echo "Dominio: $DOMAIN_NAME"
echo "Email: $SSL_EMAIL"
echo ""

# Paso 1: Iniciar servicios sin SSL
echo "Paso 1: Iniciando servicios (sin SSL)..."
docker compose up -d postgres n8n nginx

echo "Esperando 10 segundos para que los servicios inicien..."
sleep 10

# Paso 2: Obtener certificado SSL (staging primero)
echo ""
echo "Paso 2: Obteniendo certificado SSL de prueba (staging)..."
echo "Nota: Esto es una prueba. Si funciona, ejecutaremos el comando real."
echo ""

read -p "¿Continuar con certificado de prueba? (s/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
    docker compose run --rm certbot
    
    echo ""
    echo "¿El certificado de prueba se obtuvo correctamente?"
    read -p "¿Continuar con certificado real? (s/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        # Actualizar .env para producción
        sed -i 's/CERTBOT_STAGING=--staging/CERTBOT_STAGING=/' .env
        
        echo "Obteniendo certificado real..."
        docker compose run --rm certbot
        
        # Paso 3: Actualizar configuración de Nginx
        echo ""
        echo "Paso 3: Actualizando configuración de Nginx con SSL..."
        
        # Reemplazar dominio en la configuración SSL
        sed "s/n8n.tudominio.com/$DOMAIN_NAME/g" nginx-conf/n8n-ssl.conf.example > nginx-conf/n8n-ssl.conf
        
        # Backup de configuración actual
        mv nginx-conf/n8n.conf nginx-conf/n8n.conf.bak
        
        # Activar configuración SSL
        mv nginx-conf/n8n-ssl.conf nginx-conf/n8n.conf
        
        # Reiniciar Nginx
        docker compose restart nginx
        
        echo ""
        echo "=========================================="
        echo "  ¡SSL configurado exitosamente!"
        echo "=========================================="
        echo ""
        echo "Tu n8n está disponible en: https://$DOMAIN_NAME"
        echo ""
        echo "Recuerda actualizar en .env:"
        echo "  WEBHOOK_URL=https://$DOMAIN_NAME"
        echo "  N8N_SECURE_COOKIE=true"
        echo ""
        echo "Luego reinicia n8n:"
        echo "  docker compose restart n8n"
        echo ""
    fi
else
    echo "Operación cancelada"
    exit 0
fi
