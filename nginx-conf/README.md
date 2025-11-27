# Configuraciones de Nginx

Este directorio contiene las configuraciones de Nginx para n8n.

## Archivos

### n8n.conf
Configuración inicial de Nginx (sin SSL).

**Uso**: 
- Primera instalación
- Obtención de certificados SSL
- Desarrollo local

**Características**:
- Escucha en puerto 80
- Permite validación de Certbot (/.well-known/acme-challenge)
- Proxy directo a n8n:5678

### n8n-ssl.conf.example
Template de configuración con SSL/HTTPS.

**Uso**:
- Después de obtener certificados SSL
- Producción con HTTPS

**Características**:
- Redirige HTTP (80) → HTTPS (443)
- Configuración SSL optimizada (TLS 1.2/1.3)
- Headers de seguridad
- WebSocket support
- Timeouts para workflows largos

## Flujo de Configuración

### 1. Inicio (sin SSL)
```
n8n.conf → Puerto 80 → n8n:5678
```

### 2. Obtener Certificados
```
Certbot → /.well-known/acme-challenge → Validación
```

### 3. Producción (con SSL)
```
n8n-ssl.conf → Puerto 443 (HTTPS) → n8n:5678
              → Puerto 80 (HTTP) → Redirect a HTTPS
```

## Cambiar de HTTP a HTTPS

### Método Automático
```bash
./ssl-setup.sh
```

### Método Manual
```bash
# 1. Obtener certificados SSL
docker compose run --rm certbot

# 2. Reemplazar dominio en template
sed "s/n8n.tudominio.com/TU_DOMINIO/g" \
    n8n-ssl.conf.example > n8n-ssl.conf

# 3. Backup de configuración actual
mv n8n.conf n8n.conf.bak

# 4. Activar configuración SSL
mv n8n-ssl.conf n8n.conf

# 5. Reiniciar Nginx
docker compose restart nginx
```

## Personalización

### Cambiar Dominio
Editar en `n8n-ssl.conf`:
```nginx
server_name n8n.tudominio.com;
ssl_certificate /etc/letsencrypt/live/n8n.tudominio.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/n8n.tudominio.com/privkey.pem;
```

### Ajustar Timeouts
Para workflows muy largos:
```nginx
proxy_connect_timeout 600;
proxy_send_timeout 600;
proxy_read_timeout 600;
send_timeout 600;
```

### Aumentar Tamaño de Carga
Para archivos grandes:
```nginx
client_max_body_size 100M;
```

### Headers de Seguridad Adicionales
```nginx
add_header Content-Security-Policy "default-src 'self';" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

## Verificar Configuración

```bash
# Verificar sintaxis
docker compose exec nginx nginx -t

# Recargar sin reiniciar
docker compose exec nginx nginx -s reload

# Ver logs
docker compose logs nginx
```

## Troubleshooting

### Error: "certificate not found"
Verificar que los certificados existen:
```bash
docker compose exec nginx ls -la /etc/letsencrypt/live/
```

### Error: "upstream not found"
Verificar que n8n está corriendo:
```bash
docker compose ps n8n
```

### Error: "connection refused"
Verificar conectividad entre contenedores:
```bash
docker compose exec nginx ping n8n
```

## Referencias

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
