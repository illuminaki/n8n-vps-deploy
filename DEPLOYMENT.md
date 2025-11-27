# Guía de Deployment en Hetzner VPS

Guía completa paso a paso para desplegar n8n en un servidor VPS de Hetzner.

## Tabla de Contenidos

- [Requisitos Previos](#requisitos-previos)
- [Paso 1: Crear el VPS en Hetzner](#paso-1-crear-el-vps-en-hetzner)
- [Paso 2: Configuración Inicial del Servidor](#paso-2-configuración-inicial-del-servidor)
- [Paso 3: Desplegar n8n](#paso-3-desplegar-n8n)
- [Paso 4: Configurar Dominio y SSL](#paso-4-configurar-dominio-y-ssl)
- [Seguridad](#seguridad)
- [Mantenimiento](#mantenimiento)
- [Troubleshooting](#troubleshooting)

## Requisitos Previos

- Cuenta en [Hetzner Cloud](https://www.hetzner.com/cloud)
- Conocimientos básicos de Linux/Ubuntu
- Dominio propio (opcional, pero recomendado para producción)
- Cliente SSH instalado en tu computadora

## Paso 1: Crear el VPS en Hetzner

### 1.1 Acceder a Hetzner Cloud Console

1. Ve a [https://console.hetzner.cloud](https://console.hetzner.cloud)
2. Inicia sesión con tu cuenta
3. Crea un nuevo proyecto o selecciona uno existente

### 1.2 Crear un Nuevo Servidor

1. Click en **"Add Server"**

2. **Ubicación**: Elige la más cercana a tus usuarios
   - Nuremberg, Alemania
   - Helsinki, Finlandia
   - Falkenstein, Alemania
   - Ashburn, USA

3. **Imagen del Sistema**: Ubuntu 22.04 LTS

4. **Tipo de Servidor** (elige según tus necesidades):
   
   | Plan | vCPU | RAM | Disco | Precio/mes | Recomendado para |
   |------|------|-----|-------|------------|------------------|
   | CX11 | 1 | 2GB | 20GB | €4.15 | Testing |
   | CPX11 | 2 | 2GB | 40GB | €4.75 | Desarrollo |
   | CPX21 | 3 | 4GB | 80GB | €8.21 | **Producción** |
   | CPX31 | 4 | 8GB | 160GB | €15.50 | Alta carga |

5. **Networking**:
   - IPv4 habilitado
   - IPv6 habilitado (opcional)

6. **SSH Keys**:
   - Añade tu clave pública SSH
   - Si no tienes una, créala en tu computadora:
     ```bash
     ssh-keygen -t ed25519 -C "tu-email@ejemplo.com"
     cat ~/.ssh/id_ed25519.pub
     ```

7. **Nombre del servidor**: `n8n-production` (o el que prefieras)

8. Click en **"Create & Buy now"**

### 1.3 Configurar Firewall (Recomendado)

1. En el panel lateral, ve a **"Firewalls"**
2. Click en **"Create Firewall"**
3. Nombre: `n8n-firewall`
4. Configura las siguientes reglas **Inbound**:

   | Protocolo | Puerto | Fuente | Descripción |
   |-----------|--------|--------|-------------|
   | TCP | 22 | 0.0.0.0/0, ::/0 | SSH |
   | TCP | 80 | 0.0.0.0/0, ::/0 | HTTP |
   | TCP | 443 | 0.0.0.0/0, ::/0 | HTTPS |
   | TCP | 5678 | 0.0.0.0/0, ::/0 | n8n (temporal) |

5. Aplica el firewall a tu servidor

### 1.4 Anotar Información del Servidor

Una vez creado el servidor, anota:
- **IP pública del servidor**: `XXX.XXX.XXX.XXX`
- **Usuario**: `root`
- **Región**: (ejemplo: Nuremberg)

---

## Paso 2: Configuración Inicial del Servidor

### 2.1 Conectar por SSH

Desde tu terminal local:

```bash
ssh root@TU_IP_DEL_SERVIDOR
```

Si es la primera vez, acepta la huella digital del servidor (fingerprint).

### 2.2 Actualizar el Sistema

```bash
# Actualizar lista de paquetes
apt update

# Actualizar todos los paquetes instalados
apt upgrade -y

# Reiniciar si es necesario
# reboot
```

### 2.3 Instalar Docker

```bash
# Instalar dependencias necesarias
apt install -y apt-transport-https ca-certificates curl software-properties-common

# Añadir la clave GPG oficial de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Añadir el repositorio de Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Actualizar el índice de paquetes
apt update

# Instalar Docker
apt install -y docker-ce docker-ce-cli containerd.io

# Verificar que Docker está instalado
docker --version
# Debería mostrar: Docker version 24.x.x

# Habilitar Docker para que inicie automáticamente
systemctl enable docker
systemctl start docker
```

### 2.4 Instalar Docker Compose

```bash
# Crear directorio para plugins de Docker CLI
mkdir -p /usr/local/lib/docker/cli-plugins

# Descargar Docker Compose
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose

# Dar permisos de ejecución
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verificar instalación
docker compose version
# Debería mostrar: Docker Compose version v2.x.x
```

### 2.5 Crear Usuario No-Root (Recomendado)

Por seguridad, es mejor no usar el usuario root:

```bash
# Crear nuevo usuario
adduser n8nuser
# Sigue las instrucciones para crear la contraseña

# Añadir usuario a grupos necesarios
usermod -aG sudo n8nuser
usermod -aG docker n8nuser

# Copiar claves SSH al nuevo usuario
rsync --archive --chown=n8nuser:n8nuser ~/.ssh /home/n8nuser

# Cambiar al nuevo usuario
su - n8nuser

# Verificar acceso a Docker
docker ps
```

**Nota**: A partir de aquí, todos los comandos se ejecutan como `n8nuser` (o el usuario que creaste).

---

## Paso 3: Desplegar n8n

### 3.1 Clonar o Subir el Proyecto

**Opción A: Clonar desde GitHub** (si tu proyecto está en GitHub)

```bash
# Instalar git si no está instalado
sudo apt install -y git

# Clonar el repositorio
git clone https://github.com/TU_USUARIO/n8n-vps-deploy.git
cd n8n-vps-deploy
```

**Opción B: Crear Manualmente**

```bash
# Crear directorio del proyecto
mkdir -p ~/n8n-deployment
cd ~/n8n-deployment

# Crear docker-compose.yml
nano docker-compose.yml
# Copia el contenido del archivo docker-compose.yml de este repositorio

# Crear .env.example
nano .env.example
# Copia el contenido del archivo .env.example de este repositorio
```

**Opción C: Transferir archivos con SCP** (desde tu computadora local)

```bash
# Desde tu computadora local
scp docker-compose.yml n8nuser@TU_IP:/home/n8nuser/n8n-deployment/
scp .env.example n8nuser@TU_IP:/home/n8nuser/n8n-deployment/
```

### 3.2 Configurar Variables de Entorno

```bash
# Copiar el archivo de ejemplo
cp .env.example .env

# Editar el archivo .env
nano .env
```

**Configuración mínima requerida**:

```bash
# Zonas horarias (ajusta a tu región)
TZ=America/Bogota
GENERIC_TIMEZONE=America/Bogota

# Puerto de exposición
N8N_PORT=5678

# URL de webhooks - IMPORTANTE: Usa tu IP o dominio
WEBHOOK_URL=http://TU_IP_DEL_SERVIDOR:5678
# Para producción con dominio:
# WEBHOOK_URL=https://n8n.tudominio.com

# Nivel de logs
N8N_LOG_LEVEL=info

# Cookies seguras (solo con HTTPS)
N8N_SECURE_COOKIE=false
# Para producción con HTTPS:
# N8N_SECURE_COOKIE=true

# PostgreSQL - CAMBIA ESTAS CREDENCIALES
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=TuPasswordSuperSegura123!@#
DB_POSTGRESDB_SCHEMA=public
```

### 3.3 Generar Clave de Encriptación

```bash
# Generar clave aleatoria y añadirla al .env
echo "N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env

# Verificar que se añadió
tail -n 1 .env
```

### 3.4 Iniciar n8n

```bash
# Iniciar los contenedores en modo detached (segundo plano)
docker compose up -d

# Ver los logs en tiempo real
docker compose logs -f

# Para salir de los logs: Ctrl + C
```

### 3.5 Verificar el Deployment

```bash
# Ver estado de los contenedores
docker compose ps
# Ambos contenedores deben estar "Up"

# Ver logs de n8n
docker compose logs n8n

# Ver logs de PostgreSQL
docker compose logs postgres

# Verificar que n8n está escuchando
curl http://localhost:5678
# Debería devolver HTML
```

### 3.6 Acceder a n8n

1. Abre tu navegador
2. Ve a: `http://TU_IP_DEL_SERVIDOR:5678`
3. Crea tu cuenta de administrador
4. ¡Comienza a crear workflows!

---

## Paso 4: Configurar Dominio y SSL (Producción)

### 4.1 Configurar DNS

En tu proveedor de dominio (GoDaddy, Namecheap, Cloudflare, etc.):

1. Crea un registro **A**:
   ```
   Tipo: A
   Nombre: n8n (o @ para usar el dominio raíz)
   Valor: TU_IP_DEL_SERVIDOR
   TTL: 3600
   ```

2. Espera a que se propague (puede tomar 5-30 minutos)

3. Verifica la propagación:
   ```bash
   # Desde tu computadora local
   nslookup n8n.tudominio.com
   # Debe mostrar tu IP del servidor
   ```

### 4.2 Instalar Nginx

```bash
sudo apt update
sudo apt install -y nginx
```

### 4.3 Configurar Nginx como Reverse Proxy

```bash
# Crear archivo de configuración
sudo nano /etc/nginx/sites-available/n8n
```

Añade esta configuración:

```nginx
server {
    listen 80;
    server_name n8n.tudominio.com;

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        
        # Headers para webhooks
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        send_timeout 300;
    }
}
```

Guardar: `Ctrl + O`, Enter, `Ctrl + X`

```bash
# Crear enlace simbólico para activar el sitio
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Verificar configuración
sudo nginx -t

# Reiniciar Nginx
sudo systemctl restart nginx

# Habilitar Nginx al inicio
sudo systemctl enable nginx
```

### 4.4 Instalar Certbot para SSL

```bash
# Instalar Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtener certificado SSL
sudo certbot --nginx -d n8n.tudominio.com

# Sigue las instrucciones:
# - Ingresa tu email
# - Acepta los términos
# - Elige si quieres compartir tu email (opcional)
# - Elige opción 2: Redirect (redirigir HTTP a HTTPS)
```

### 4.5 Actualizar Configuración de n8n

```bash
# Editar .env
nano .env
```

Actualiza estas variables:

```bash
WEBHOOK_URL=https://n8n.tudominio.com
N8N_SECURE_COOKIE=true
```

```bash
# Reiniciar n8n para aplicar cambios
docker compose down
docker compose up -d
```

### 4.6 Verificar SSL

1. Abre tu navegador
2. Ve a: `https://n8n.tudominio.com`
3. Verifica que el candado SSL esté presente
4. Verifica que HTTP redirija a HTTPS

### 4.7 Configurar Renovación Automática de SSL

```bash
# Verificar que el timer de renovación está activo
sudo systemctl status certbot.timer

# Probar renovación (dry-run)
sudo certbot renew --dry-run
```

Certbot renovará automáticamente los certificados antes de que expiren.

---

## Seguridad

### Configurar Firewall UFW (Adicional)

```bash
# Instalar UFW
sudo apt install -y ufw

# Configurar reglas por defecto
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Permitir SSH (¡IMPORTANTE! No te bloquees)
sudo ufw allow ssh
sudo ufw allow 22/tcp

# Permitir HTTP y HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Si accedes directamente por el puerto 5678 (no recomendado en producción)
# sudo ufw allow 5678/tcp

# Activar firewall
sudo ufw enable

# Verificar estado
sudo ufw status verbose
```

### Cambiar Puerto SSH (Opcional)

```bash
# Editar configuración SSH
sudo nano /etc/ssh/sshd_config

# Cambiar la línea:
# Port 22
# Por:
# Port 2222  # O el puerto que prefieras

# Reiniciar SSH
sudo systemctl restart sshd

# Actualizar firewall
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp
```

### Deshabilitar Login Root por SSH

```bash
# Editar configuración SSH
sudo nano /etc/ssh/sshd_config

# Cambiar:
# PermitRootLogin yes
# Por:
# PermitRootLogin no

# Reiniciar SSH
sudo systemctl restart sshd
```

### Configurar Fail2Ban

```bash
# Instalar Fail2Ban
sudo apt install -y fail2ban

# Copiar configuración
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Editar configuración
sudo nano /etc/fail2ban/jail.local

# Buscar [sshd] y asegúrate que esté enabled = true

# Iniciar y habilitar Fail2Ban
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

# Verificar estado
sudo fail2ban-client status
```

---

## Mantenimiento

### Backups Automáticos

#### Crear Script de Backup

```bash
# Crear directorio para backups
mkdir -p ~/n8n-backups

# Crear script
nano ~/backup-n8n.sh
```

Contenido del script:

```bash
#!/bin/bash

BACKUP_DIR=~/n8n-backups
PROJECT_DIR=~/n8n-deployment
DATE=$(date +%Y%m%d_%H%M%S)

# Crear directorio si no existe
mkdir -p $BACKUP_DIR

# Backup de PostgreSQL
docker compose -f $PROJECT_DIR/docker-compose.yml exec -T postgres \
  pg_dump -U n8n_user n8n > $BACKUP_DIR/db_$DATE.sql

# Backup de volumen de datos de n8n
docker run --rm \
  -v n8n-vps-deploy_n8n_data:/data \
  -v $BACKUP_DIR:/backup \
  ubuntu tar czf /backup/n8n_data_$DATE.tar.gz /data

# Comprimir backup de base de datos
gzip $BACKUP_DIR/db_$DATE.sql

# Mantener solo últimos 7 días
find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completado: $DATE"
```

```bash
# Dar permisos de ejecución
chmod +x ~/backup-n8n.sh

# Probar el script
./backup-n8n.sh
```

#### Configurar Cron para Backups Automáticos

```bash
# Editar crontab
crontab -e

# Añadir esta línea (backup diario a las 2 AM)
0 2 * * * /home/n8nuser/backup-n8n.sh >> /home/n8nuser/backup-n8n.log 2>&1
```

### Actualizar n8n

```bash
cd ~/n8n-deployment

# Hacer backup antes de actualizar
~/backup-n8n.sh

# Descargar última versión de las imágenes
docker compose pull

# Detener contenedores
docker compose down

# Iniciar con nuevas versiones
docker compose up -d

# Verificar logs
docker compose logs -f n8n
```

### Monitoreo

```bash
# Ver uso de recursos de contenedores
docker stats

# Ver espacio en disco
df -h

# Ver logs de errores
docker compose logs --tail=100 n8n | grep -i error

# Ver logs de PostgreSQL
docker compose logs --tail=50 postgres
```

---

## Troubleshooting

### No puedo conectarme por SSH

```bash
# Desde tu computadora local, verifica conectividad
ping TU_IP_DEL_SERVIDOR

# Verifica que el puerto SSH esté abierto
telnet TU_IP_DEL_SERVIDOR 22

# Verifica el firewall de Hetzner en la consola web
```

### n8n no es accesible desde internet

```bash
# Verificar que n8n está corriendo
docker compose ps

# Verificar que está escuchando en el puerto
sudo netstat -tulpn | grep 5678

# Verificar firewall
sudo ufw status

# Verificar logs de Nginx
sudo tail -f /var/log/nginx/error.log
```

### Error de certificado SSL

```bash
# Ver logs de Certbot
sudo certbot certificates

# Renovar manualmente
sudo certbot renew --force-renewal

# Verificar configuración de Nginx
sudo nginx -t
```

### PostgreSQL no inicia

```bash
# Ver logs
docker compose logs postgres

# Verificar espacio en disco
df -h

# Reiniciar contenedor
docker compose restart postgres
```

### Restaurar desde Backup

```bash
# Detener n8n
docker compose down

# Restaurar base de datos
gunzip -c ~/n8n-backups/db_FECHA.sql.gz | \
  docker compose exec -T postgres psql -U n8n_user n8n

# Restaurar datos de n8n
docker run --rm \
  -v n8n-vps-deploy_n8n_data:/data \
  -v ~/n8n-backups:/backup \
  ubuntu tar xzf /backup/n8n_data_FECHA.tar.gz -C /

# Iniciar n8n
docker compose up -d
```

---

## Referencias Útiles

- [Documentación oficial de n8n](https://docs.n8n.io/)
- [n8n Server Setup - Hetzner](https://docs.n8n.io/hosting/installation/server-setups/hetzner/)
- [Hetzner Cloud Docs](https://docs.hetzner.com/cloud/)
- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Certbot Documentation](https://certbot.eff.org/docs/)

---

**¿Problemas?** Revisa la sección de [Troubleshooting](#troubleshooting) o consulta la documentación oficial.
