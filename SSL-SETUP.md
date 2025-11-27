# Configuración SSL con Nginx y Certbot

Guía para configurar SSL/HTTPS automático con Let's Encrypt para n8n.

## Tabla de Contenidos

- [Requisitos Previos](#requisitos-previos)
- [Configuración Rápida](#configuración-rápida)
- [Configuración Manual](#configuración-manual)
- [Renovación Automática](#renovación-automática)
- [Troubleshooting](#troubleshooting)

## Requisitos Previos

1. **Dominio configurado**: Tu dominio debe apuntar a la IP del servidor
   ```bash
   # Verificar DNS
   nslookup n8n.tudominio.com
   ```

2. **Puertos abiertos**: 80 y 443 deben estar accesibles
   ```bash
   # Verificar firewall
   sudo ufw status
   ```

3. **Variables configuradas en .env**:
   ```bash
   DOMAIN_NAME=n8n.tudominio.com
   SSL_EMAIL=tu-email@ejemplo.com
   WEBHOOK_URL=https://n8n.tudominio.com
   N8N_SECURE_COOKIE=true
   ```

## Configuración Rápida

### Opción 1: Script Automático (Recomendado)

```bash
# 1. Configurar .env
cp .env.example .env
nano .env

# 2. Ejecutar script de configuración SSL
./ssl-setup.sh
```

El script:
- Inicia los servicios necesarios
- Obtiene certificado de prueba (staging)
- Si funciona, obtiene certificado real
- Configura Nginx automáticamente
- Reinicia los servicios

### Opción 2: Paso a Paso Manual

Ver sección [Configuración Manual](#configuración-manual) más abajo.

## Configuración Manual

### Paso 1: Configurar Variables de Entorno

```bash
# Editar .env
nano .env
```

Configurar:
```bash
DOMAIN_NAME=n8n.tudominio.com
SSL_EMAIL=tu-email@ejemplo.com
CERTBOT_STAGING=--staging  # Para pruebas
WEBHOOK_URL=https://n8n.tudominio.com
N8N_SECURE_COOKIE=true
N8N_ENCRYPTION_KEY=tu-clave-generada
```

### Paso 2: Generar Clave de Encriptación

```bash
echo "N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env
```

### Paso 3: Iniciar Servicios (Sin SSL)

```bash
# Iniciar PostgreSQL, n8n y Nginx
docker compose up -d postgres n8n nginx

# Verificar que están corriendo
docker compose ps
```

### Paso 4: Obtener Certificado de Prueba

```bash
# Primero probar con staging (no cuenta para límites de rate)
docker compose run --rm certbot

# Verificar logs
docker compose logs certbot
```

Si hay errores, revisar:
- DNS está configurado correctamente
- Puerto 80 está abierto
- Nginx está corriendo

### Paso 5: Obtener Certificado Real

```bash
# Editar .env y quitar --staging
nano .env
# Cambiar: CERTBOT_STAGING=--staging
# Por:     CERTBOT_STAGING=

# Obtener certificado real
docker compose run --rm certbot
```

### Paso 6: Configurar Nginx con SSL

```bash
# Reemplazar dominio en configuración SSL
sed "s/n8n.tudominio.com/$DOMAIN_NAME/g" \
    nginx-conf/n8n-ssl.conf.example > nginx-conf/n8n-ssl.conf

# Backup de configuración actual
mv nginx-conf/n8n.conf nginx-conf/n8n.conf.bak

# Activar configuración SSL
mv nginx-conf/n8n-ssl.conf nginx-conf/n8n.conf

# Reiniciar Nginx
docker compose restart nginx
```

### Paso 7: Verificar Configuración

```bash
# Verificar certificados
docker compose exec nginx ls -la /etc/letsencrypt/live/

# Verificar configuración de Nginx
docker compose exec nginx nginx -t

# Ver logs
docker compose logs nginx
```

### Paso 8: Acceder a n8n

Abre tu navegador en: `https://n8n.tudominio.com`

## Renovación Automática

### Opción 1: Script de Renovación

```bash
# Probar renovación manual
./ssl-renew.sh

# Agregar a crontab para renovación automática
crontab -e

# Añadir esta línea (renovar cada día a las 3 AM)
0 3 * * * /ruta/completa/al/proyecto/ssl-renew.sh >> /var/log/ssl-renew.log 2>&1
```

### Opción 2: Servicio de Docker Compose

Agregar al `docker-compose.yml`:

```yaml
  certbot-renew:
    image: certbot/certbot:latest
    container_name: n8n-certbot-renew
    volumes:
      - certbot-etc:/etc/letsencrypt
      - certbot-var:/var/lib/letsencrypt
      - web-root:/var/www/html
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
```

## Arquitectura

```
Internet
   |
   v
[Puerto 80/443]
   |
   v
[Nginx Container]
   |
   +-- SSL/TLS Termination
   |
   v
[n8n Container:5678]
   |
   v
[PostgreSQL Container]
```

## Configuración de Nginx

### Configuración Inicial (sin SSL)

`nginx-conf/n8n.conf`:
- Escucha en puerto 80
- Permite validación de Certbot (/.well-known/acme-challenge)
- Proxy a n8n para acceso temporal

### Configuración con SSL

`nginx-conf/n8n-ssl.conf.example`:
- Redirige HTTP (80) a HTTPS (443)
- Configuración SSL/TLS optimizada
- Headers de seguridad
- WebSocket support para n8n
- Timeouts para workflows largos

## Variables de Entorno

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `DOMAIN_NAME` | Dominio para n8n | `n8n.tudominio.com` |
| `SSL_EMAIL` | Email para Let's Encrypt | `admin@tudominio.com` |
| `CERTBOT_STAGING` | Usar staging (pruebas) | `--staging` o vacío |
| `WEBHOOK_URL` | URL pública de n8n | `https://n8n.tudominio.com` |
| `N8N_SECURE_COOKIE` | Cookies seguras | `true` |

## Troubleshooting

### Error: "DNS problem: NXDOMAIN"

**Problema**: El dominio no resuelve a la IP del servidor.

**Solución**:
```bash
# Verificar DNS
nslookup n8n.tudominio.com

# Esperar propagación DNS (puede tomar hasta 48h)
# Verificar en: https://dnschecker.org/
```

### Error: "Connection refused"

**Problema**: Puerto 80 no está accesible.

**Solución**:
```bash
# Verificar que Nginx está corriendo
docker compose ps nginx

# Verificar firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Verificar que el puerto está escuchando
sudo netstat -tulpn | grep :80
```

### Error: "Rate limit exceeded"

**Problema**: Demasiados intentos con certificado real.

**Solución**:
```bash
# Usar staging para pruebas
# En .env: CERTBOT_STAGING=--staging

# Limpiar certificados anteriores
docker compose down
docker volume rm n8n-vps-deploy_certbot-etc

# Intentar de nuevo con staging
docker compose up -d
docker compose run --rm certbot
```

### Error: "Certificate not found"

**Problema**: Nginx no encuentra los certificados.

**Solución**:
```bash
# Verificar que los certificados existen
docker compose exec nginx ls -la /etc/letsencrypt/live/

# Verificar nombre del dominio en configuración
cat nginx-conf/n8n.conf | grep ssl_certificate

# Debe coincidir con el dominio en .env
```

### Nginx no inicia después de configurar SSL

**Problema**: Configuración SSL incorrecta.

**Solución**:
```bash
# Verificar configuración
docker compose exec nginx nginx -t

# Ver logs de error
docker compose logs nginx

# Restaurar configuración anterior
mv nginx-conf/n8n.conf.bak nginx-conf/n8n.conf
docker compose restart nginx
```

### n8n no es accesible después de SSL

**Problema**: Variables de entorno no actualizadas.

**Solución**:
```bash
# Verificar .env
cat .env | grep WEBHOOK_URL
cat .env | grep N8N_SECURE_COOKIE

# Deben ser:
# WEBHOOK_URL=https://n8n.tudominio.com
# N8N_SECURE_COOKIE=true

# Reiniciar n8n
docker compose restart n8n
```

## Comandos Útiles

```bash
# Ver certificados instalados
docker compose exec nginx ls -la /etc/letsencrypt/live/

# Ver logs de Certbot
docker compose logs certbot

# Ver logs de Nginx
docker compose logs nginx

# Probar configuración de Nginx
docker compose exec nginx nginx -t

# Recargar configuración de Nginx (sin reiniciar)
docker compose exec nginx nginx -s reload

# Renovar certificados manualmente
docker compose run --rm certbot renew

# Ver fecha de expiración de certificados
docker compose exec nginx openssl x509 -in /etc/letsencrypt/live/n8n.tudominio.com/cert.pem -noout -dates
```

## Seguridad Adicional

### Headers de Seguridad

Ya incluidos en `n8n-ssl.conf.example`:
- `Strict-Transport-Security` (HSTS)
- `X-Frame-Options`
- `X-Content-Type-Options`
- `X-XSS-Protection`

### Configuración SSL Recomendada

- TLS 1.2 y 1.3 únicamente
- Ciphers seguros (ECDHE)
- Session cache optimizado
- HSTS habilitado

### Verificar Seguridad SSL

```bash
# Verificar configuración SSL en línea
# https://www.ssllabs.com/ssltest/

# Verificar headers de seguridad
curl -I https://n8n.tudominio.com
```

## Referencias

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://certbot.eff.org/docs/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [n8n Security Best Practices](https://docs.n8n.io/hosting/security/)
