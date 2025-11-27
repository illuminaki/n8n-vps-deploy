# n8n VPS Deployment

Configuración de n8n con PostgreSQL usando Docker Compose, lista para desplegar en producción.

## Tabla de Contenidos

- [Descripción](#descripción)
- [Stack Tecnológico](#stack-tecnológico)
- [Requisitos](#requisitos)
- [Inicio Rápido](#inicio-rápido)
- [Configuración](#configuración)
- [Comandos Útiles](#comandos-útiles)
- [Deployment en VPS](#deployment-en-vps)
- [Troubleshooting](#troubleshooting)

## Descripción

Configuración de n8n (plataforma de automatización de workflows) con PostgreSQL, lista para desarrollo local y producción en VPS.

**Características**:
- n8n con PostgreSQL para persistencia
- Docker Compose para fácil deployment
- Variables de entorno configurables
- Volúmenes persistentes para datos
- Configuración lista para SSL/HTTPS

## Stack Tecnológico

| Componente | Versión | Descripción |
|------------|---------|-------------|
| **n8n** | Latest | Plataforma de automatización de workflows |
| **PostgreSQL** | 16-alpine | Base de datos relacional |
| **Docker** | 20.10+ | Containerización |
| **Docker Compose** | 2.0+ | Orquestación de contenedores |

**Adicionales para producción**:
- **Nginx**: Reverse proxy
- **Certbot**: Certificados SSL gratuitos

## Requisitos

- Docker 20.10 o superior
- Docker Compose 2.0 o superior
- 2GB RAM mínimo (4GB recomendado para producción)
- Puertos disponibles: 5678

## Inicio Rápido

### 1. Clonar el Repositorio

```bash
git clone https://github.com/TU_USUARIO/n8n-vps-deploy.git
cd n8n-vps-deploy
```

### 2. Configurar Variables de Entorno

```bash
# Copiar archivo de ejemplo
cp .env.example .env

# Editar variables
nano .env
```

**Variables principales a configurar**:

```bash
# Zona horaria
TZ=America/Bogota
GENERIC_TIMEZONE=America/Bogota

# URL de webhooks (usa tu IP o dominio)
WEBHOOK_URL=http://localhost:5678

# Credenciales de PostgreSQL (¡CÁMBIALAS!)
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=TuPasswordSegura123!
DB_POSTGRESDB_SCHEMA=public
```

### 3. Generar Clave de Encriptación

```bash
echo "N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env
```

### 4. Iniciar n8n

```bash
# Iniciar contenedores
docker compose up -d

# Ver logs
docker compose logs -f n8n
```

### 5. Acceder a n8n

Abre tu navegador en: **http://localhost:5678**

Crea tu cuenta de administrador y comienza a crear workflows.

## Configuración

### Variables de Entorno Importantes

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `TZ` | Zona horaria | `America/Bogota` |
| `WEBHOOK_URL` | URL pública de n8n | `https://n8n.tudominio.com` |
| `N8N_SECURE_COOKIE` | Cookies seguras (HTTPS) | `true` |
| `DB_POSTGRESDB_PASSWORD` | Password de PostgreSQL | `TuPasswordSegura123!` |
| `N8N_ENCRYPTION_KEY` | Clave de encriptación | `generada-aleatoriamente` |

### Archivo `.env` Completo

Ver `.env.example` para todas las opciones disponibles.

**Configuración avanzada**: [Documentación oficial de n8n](https://docs.n8n.io/hosting/configuration/)

## Comandos Útiles

### Gestión de Contenedores

```bash
# Iniciar servicios
docker compose up -d

# Detener servicios
docker compose down

# Reiniciar servicios
docker compose restart

# Ver estado
docker compose ps

# Ver logs en tiempo real
docker compose logs -f n8n

# Ver logs de PostgreSQL
docker compose logs -f postgres
```

### Actualización

```bash
# Descargar última versión
docker compose pull

# Aplicar actualización
docker compose down
docker compose up -d
```

### Backup Manual

```bash
# Backup de PostgreSQL
docker compose exec postgres pg_dump -U n8n_user n8n > backup_n8n_$(date +%Y%m%d).sql

# Backup de volumen de datos
docker run --rm -v n8n-vps-deploy_n8n_data:/data -v $(pwd):/backup ubuntu tar czf /backup/n8n_data_$(date +%Y%m%d).tar.gz /data
```

### Monitoreo

```bash
# Ver uso de recursos
docker stats

# Ver espacio en disco
df -h

# Ver logs de errores
docker compose logs --tail=100 n8n | grep -i error
```

## Configuración SSL/HTTPS

Este proyecto incluye Nginx y Certbot para SSL automático con Let's Encrypt.

### Configuración Rápida SSL

```bash
# 1. Configurar dominio en .env
DOMAIN_NAME=n8n.tudominio.com
SSL_EMAIL=tu-email@ejemplo.com

# 2. Ejecutar script de configuración
./ssl-setup.sh
```

**[SSL-SETUP.md](./SSL-SETUP.md)** - Guía completa de configuración SSL

### Arquitectura con SSL

```
Internet → Nginx (80/443) → n8n (5678) → PostgreSQL
           ↓
       Certbot (SSL)
```

## Deployment en VPS

Para desplegar n8n en un servidor VPS de Hetzner (o cualquier otro proveedor), consulta la guía completa:

**[DEPLOYMENT.md](./DEPLOYMENT.md)** - Guía paso a paso de deployment en VPS

La guía incluye:
- Creación y configuración del VPS en Hetzner
- Instalación de Docker y Docker Compose
- Configuración de dominio y SSL/HTTPS con Nginx y Certbot
- Mejores prácticas de seguridad
- Configuración de backups automáticos
- Troubleshooting común

## Troubleshooting

### Variables de entorno no configuradas

Si ves warnings sobre variables no configuradas:

```bash
# Asegúrate de que existe el archivo .env
ls -la .env

# Si no existe, cópialo desde el ejemplo
cp .env.example .env

# Edita las variables según tus necesidades
nano .env
```

### Conflicto con contenedores existentes

Si ves el error "container name is already in use":

```bash
# Opción 1: Detener y eliminar contenedores antiguos
docker rm -f n8n n8n-postgres

# Opción 2: Limpiar todo (cuidado: elimina datos)
docker compose down -v

# Luego inicia de nuevo
docker compose up -d
```

### n8n no inicia

```bash
# Ver logs detallados
docker compose logs n8n

# Verificar variables de entorno
docker compose config

# Reiniciar desde cero
docker compose down -v
docker compose up -d
```

### Error de conexión a PostgreSQL

```bash
# Verificar que PostgreSQL está corriendo
docker compose ps postgres

# Ver logs de PostgreSQL
docker compose logs postgres

# Verificar credenciales en .env
cat .env | grep DB_POSTGRESDB
```

### Problemas con webhooks

```bash
# Verifica que WEBHOOK_URL sea accesible
echo $WEBHOOK_URL

# Revisa los logs
docker compose logs -f n8n
```

## Referencias

- **[Documentación oficial de n8n](https://docs.n8n.io/)** - Guía completa de n8n
- **[Docker Compose Docs](https://docs.docker.com/compose/)** - Documentación de Docker Compose
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Guía de deployment en VPS

## Estructura del Proyecto

```
n8n-vps-deploy/
├── docker-compose.yml           # Configuración de servicios (n8n, PostgreSQL, Nginx, Certbot)
├── .env.example                 # Plantilla de variables de entorno
├── .env                         # Variables de entorno (no versionado)
├── .gitignore                   # Archivos ignorados por git
├── nginx-conf/
│   ├── n8n.conf                # Configuración inicial de Nginx
│   └── n8n-ssl.conf.example    # Configuración con SSL (template)
├── ssl-setup.sh                 # Script automático para configurar SSL
├── ssl-renew.sh                 # Script para renovar certificados
├── README.md                    # Este archivo
├── SSL-SETUP.md                 # Guía completa de configuración SSL
└── DEPLOYMENT.md                # Guía de deployment en VPS
```

## Licencia

Este proyecto es de código abierto. n8n tiene su propia [licencia](https://github.com/n8n-io/n8n/blob/master/LICENSE.md).

---

**¿Necesitas ayuda?**
- Consulta [DEPLOYMENT.md](./DEPLOYMENT.md) para deployment en VPS
- Visita la [documentación oficial de n8n](https://docs.n8n.io/)
- Abre un issue en este repositorio