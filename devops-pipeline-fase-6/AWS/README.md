# AWS Deployment Documentation - Docker Compose Version

## 🚀 Overview

This directory contains scripts optimized for deploying the CRM system on AWS EC2 t2.micro using **Docker Compose** instead of Kubernetes. This approach is much more suitable for the limited resources of t2.micro instances.

## 📋 Architecture

```
AWS EC2 t2.micro (1GB RAM, 1 vCPU)
├── Docker Compose
│   ├── PostgreSQL 16 Alpine (200MB limit)
│   ├── Node.js Backend (120MB limit)
│   └── Nginx Frontend (50MB limit)
├── Total Usage: ~370MB (safe for 1GB)
└── Swap: 512MB for safety
```

## 🎯 Why Docker Compose vs Kubernetes?

| Aspect | Docker Compose | Kubernetes (k3s) |
|--------|----------------|-------------------|
| **Memory Usage** | ~100MB overhead | ~500MB overhead |
| **Startup Time** | 30 seconds | 5+ minutes |
| **Complexity** | Simple | Complex |
| **Troubleshooting** | Direct logs | Multiple layers |
| **Resource Efficiency** | Optimized | Heavy |

## 📁 Files Structure

```
AWS/
├── aws-manager-docker.sh      # Main management script
├── aws-setup-docker.sh        # EC2 environment setup
├── aws-monitoring-docker.sh   # Monitoring and optimization
├── README.md                  # This file
└── config/
    ├── docker-compose.yml     # Container orchestration
    ├── nginx.conf            # Nginx configuration
    └── init-db.sql           # Database schema
```

## 🚀 Quick Start

### 1. Initial Setup (Run once)
```bash
# On your EC2 instance
./aws-setup-docker.sh setup
```

### 2. Deploy CRM Application
```bash
# Complete deployment
./aws-manager-docker.sh setup
```

### 3. Access Your CRM
```bash
# Get your public IP
curl http://checkip.amazonaws.com

# Access URLs:
# Frontend: http://YOUR_IP:30002
# Backend:  http://YOUR_IP:30003/api
# Login:    admin@crm.local / admin123
```

## 🛠️ Management Commands

### aws-manager-docker.sh Commands

```bash
# Complete setup and deployment
./aws-manager-docker.sh setup

# Application management
./aws-manager-docker.sh deploy    # Deploy/redeploy
./aws-manager-docker.sh restart   # Restart services
./aws-manager-docker.sh stop      # Stop all services
./aws-manager-docker.sh status    # Check status

# Monitoring and maintenance
./aws-manager-docker.sh test      # Test all endpoints
./aws-manager-docker.sh monitor   # Resource monitoring
./aws-manager-docker.sh backup    # Database backup
./aws-manager-docker.sh logs      # View logs

# Cleanup
./aws-manager-docker.sh cleanup   # Remove everything
```

## 📊 Resource Allocation (t2.micro optimized)

| Service | Memory Limit | CPU Limit | Purpose |
|---------|-------------|-----------|---------|
| PostgreSQL | 200MB | 0.3 CPU | Database |
| Backend | 120MB | 0.3 CPU | API Server |
| Frontend | 50MB | 0.2 CPU | Web UI |
| **Total** | **370MB** | **0.8 CPU** | **System** |

**Remaining:** ~630MB RAM, 0.2 CPU for OS and overhead

## 🔧 Configuration Details

### Database Configuration (PostgreSQL)
- **Image:** postgres:16-alpine
- **Memory:** 200MB limit, 100MB reserved
- **Optimizations:**
  - shared_buffers=32MB
  - max_connections=50
  - work_mem=2MB
  - maintenance_work_mem=32MB

### Backend Configuration (Node.js)
- **Image:** node:18-alpine
- **Memory:** 120MB limit, 60MB reserved
- **Optimizations:**
  - NODE_OPTIONS="--max-old-space-size=100"
  - Production dependencies only
  - Minimal logging

### Frontend Configuration (Nginx)
- **Image:** nginx:alpine
- **Memory:** 50MB limit, 20MB reserved
- **Features:**
  - Gzip compression
  - API proxy to backend
  - Static file serving
  - Health checks

## 🌐 Network Configuration

| Port | Service | Description |
|------|---------|-------------|
| 30002 | Frontend | Web UI access |
| 30003 | Backend | API endpoints |
| 5432 | PostgreSQL | Database (internal) |

### Security Groups Required
- SSH (22): Your IP only
- HTTP (80): 0.0.0.0/0
- HTTPS (443): 0.0.0.0/0
- Custom TCP (30002): 0.0.0.0/0
- Custom TCP (30003): 0.0.0.0/0

## 💾 Data Persistence

### Database
- **Volume:** Named volume `postgres_data`
- **Backup:** Automatic daily at 2 AM
- **Retention:** 7 days compressed
- **Manual backup:** `./aws-manager-docker.sh backup`

### Application Code
- **Backend:** Bind mount `./backend`
- **Frontend:** Bind mount `./frontend`
- **Config:** Bind mount for nginx.conf

## 📈 Monitoring

### Built-in Monitoring
```bash
# System resources
./aws-manager-docker.sh monitor

# Service logs
./aws-manager-docker.sh logs [service]

# Container stats
docker stats --no-stream
```

### Automated Monitoring
- **System stats:** Logged hourly
- **Health checks:** Every 30 seconds
- **Alerts:** Memory > 90%, Disk > 85%

## 🔄 Backup Strategy

### Automatic Backups
- **Database:** Daily at 2 AM UTC
- **Configs:** Weekly snapshot
- **Retention:** 7 days for DB, 30 days for configs
- **Location:** `~/crm-backups/`

### Manual Backup
```bash
# Create immediate backup
./aws-manager-docker.sh backup

# List backups
ls -la ~/crm-backups/
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Out of Memory (OOM)
**Symptoms:** Containers restart frequently, slow performance
**Solutions:**
```bash
# Check memory usage
free -h
docker stats --no-stream

# Add more swap if needed
sudo fallocate -l 1G /swapfile2
sudo chmod 600 /swapfile2
sudo mkswap /swapfile2
sudo swapon /swapfile2

# Restart with lower memory limits
./aws-manager-docker.sh restart
```

#### 2. Database Connection Failed
**Symptoms:** Backend can't connect to PostgreSQL
**Solutions:**
```bash
# Check PostgreSQL status
docker-compose ps postgres
docker-compose logs postgres

# Test connection manually
docker-compose exec postgres pg_isready -U crm_user -d crm_db

# Restart database
docker-compose restart postgres
```

#### 3. Port Already in Use
**Symptoms:** "Port 30002 is already allocated"
**Solutions:**
```bash
# Check what's using the port
sudo netstat -tlnp | grep 30002

# Kill the process or change ports in docker-compose.yml
# Then restart
./aws-manager-docker.sh restart
```

#### 4. Disk Space Full
**Symptoms:** Cannot create files, deployment fails
**Solutions:**
```bash
# Check disk usage
df -h
docker system df

# Clean up Docker
docker system prune -f
docker volume prune -f

# Clean up logs
sudo journalctl --vacuum-time=3d
```

#### 5. Slow Performance
**Symptoms:** High load, slow response times
**Solutions:**
```bash
# Monitor resources
./aws-manager-docker.sh monitor

# Check if swap is being used heavily
swapon --show

# Consider upgrading to t3.small if needed
```

## 💡 Performance Optimization Tips

### For t2.micro
1. **Memory Management:**
   - Monitor swap usage
   - Keep total container memory < 700MB
   - Use Alpine images when possible

2. **Disk Optimization:**
   - Clean Docker images regularly
   - Compress old backups
   - Use log rotation

3. **Network Optimization:**
   - Enable gzip compression
   - Minimize API calls
   - Use connection pooling

### When to Upgrade
Consider upgrading to t3.small (2GB RAM) if:
- Swap usage consistently > 200MB
- Response times > 3 seconds
- Frequent OOM kills
- More than 10 concurrent users

## 📋 Maintenance Schedule

### Daily (Automated)
- Database backup
- Log rotation
- Health checks

### Weekly (Manual)
```bash
# System update
sudo apt update && sudo apt upgrade

# Clean up Docker
docker system prune -f

# Check disk usage
df -h
```

### Monthly (Manual)
```bash
# Review logs
tail -100 ~/aws-crm-deploy.log

# Update Docker Compose if needed
# Review and clean old backups
ls -la ~/crm-backups/
```

## 🔐 Security Considerations

### Network Security
- Firewall configured for minimal exposure
- Database not exposed externally
- API endpoints rate-limited

### Application Security
- JWT tokens with expiration
- Password hashing with bcrypt
- Input validation on all endpoints

### Infrastructure Security
- SSH key-only access
- Regular security updates
- Non-root containers

## 💰 Cost Optimization

### Free Tier (12 months)
- **EC2 t2.micro:** 750 hours/month (always on)
- **EBS:** 30GB storage
- **Data Transfer:** 15GB/month
- **Total Cost:** $0

### Post Free Tier (Monthly)
- **EC2 t2.micro:** ~$8.50
- **EBS 30GB:** ~$2.40
- **Data Transfer:** ~$1.00
- **Total Cost:** ~$12/month

### Cost Saving Tips
1. **Stop instance when not needed**
2. **Use Elastic IPs only when necessary**
3. **Monitor data transfer usage**
4. **Clean up unused EBS snapshots**

## 🔄 Scaling Options

### Vertical Scaling (Upgrade Instance)
```bash
# Stop instance
aws ec2 stop-instances --instance-ids i-1234567890abcdef0

# Change instance type
aws ec2 modify-instance-attribute --instance-id i-1234567890abcdef0 --instance-type t3.small

# Start instance
aws ec2 start-instances --instance-ids i-1234567890abcdef0
```

### Horizontal Scaling (Multiple Instances)
- Use Application Load Balancer
- Separate database to RDS
- Container orchestration with ECS

## 📞 Support

### Log Locations
- **Application:** `~/aws-crm-deploy.log`
- **System:** `~/system-monitor.log`
- **Backup:** `~/backup.log`
- **Docker:** `docker-compose logs`

### Useful Commands
```bash
# Quick health check
curl http://localhost:30003/api/health

# View all logs
tail -f ~/aws-crm-deploy.log

# Container resource usage
docker stats

# System resource usage
~/monitor-system.sh
```

## 🎯 Success Metrics

### Performance Targets
- **Page Load Time:** < 3 seconds
- **API Response Time:** < 500ms
- **Uptime:** > 99%
- **Memory Usage:** < 80%

### Monitoring Alerts
- Memory usage > 90%
- Disk usage > 85%
- Swap usage > 50%
- Response time > 2 seconds

---

## 🚀 Ready to Deploy?

1. **Setup Environment:** `./aws-setup-docker.sh setup`
2. **Deploy CRM:** `./aws-manager-docker.sh setup`
3. **Test Access:** `./aws-manager-docker.sh test`
4. **Monitor:** `./aws-manager-docker.sh monitor`

**Your CRM will be accessible at:** `http://YOUR_IP:30002`

---

*This documentation covers the Docker Compose deployment optimized for AWS EC2 t2.micro instances. For Kubernetes deployment, see the main `/devops-pipeline-fase-6/` directory.*
