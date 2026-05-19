# Docker Learning Guide - Step by Step

## What You'll Learn

1. **What is Docker?** - Containerization technology
2. **Docker Commands** - How to manage containers
3. **PostgreSQL in Docker** - Running databases in containers
4. **Networking** - How containers communicate
5. **Data Persistence** - How to save data

## Step-by-Step Learning

### Step 1: Understanding Docker

**Docker** is a platform that packages applications and their dependencies into "containers" - lightweight, portable units that run consistently anywhere.

**Why use Docker?**
- Same environment on any machine
- Easy to start/stop/remove
- Isolated from your system
- Industry standard

### Step 2: Starting Docker Desktop

Docker Desktop is the GUI application that runs Docker on Windows.

**Check if it's running:**
```powershell
docker ps
```

If you get an error, Docker Desktop isn't running. Start it from the Start menu.

### Step 3: Creating a PostgreSQL Container

**What this command does:**
```powershell
docker run --name influenza-postgres `
  -e POSTGRES_PASSWORD=influenza123 `
  -e POSTGRES_DB=influenza_db `
  -p 5432:5432 `
  -d postgres:15
```

**Breaking it down:**
- `docker run` - Create and start a new container
- `--name influenza-postgres` - Give it a friendly name
- `-e POSTGRES_PASSWORD=...` - Set environment variable (database password)
- `-e POSTGRES_DB=...` - Create a database automatically
- `-p 5432:5432` - Port mapping: host:container (expose port 5432)
- `-d` - Run in detached mode (background)
- `postgres:15` - Use PostgreSQL version 15 image

### Step 4: Managing Containers

**View running containers:**
```powershell
docker ps
```

**View all containers (including stopped):**
```powershell
docker ps -a
```

**View container logs:**
```powershell
docker logs influenza-postgres
```

**Stop a container:**
```powershell
docker stop influenza-postgres
```

**Start a stopped container:**
```powershell
docker start influenza-postgres
```

**Remove a container:**
```powershell
docker rm influenza-postgres
```

### Step 5: Connecting to Database

**Execute commands inside container:**
```powershell
docker exec influenza-postgres psql -U postgres -d influenza_db -c "SELECT version();"
```

**Interactive SQL session:**
```powershell
docker exec -it influenza-postgres psql -U postgres -d influenza_db
```

### Step 6: Understanding Port Mapping

`-p 5432:5432` means:
- **Left 5432**: Port on your computer (localhost:5432)
- **Right 5432**: Port inside the container
- **Result**: You can connect to `localhost:5432` and it forwards to the container

### Step 7: Data Persistence

By default, data is stored in the container. If you remove the container, data is lost.

**To persist data (advanced):**
```powershell
docker run --name influenza-postgres `
  -e POSTGRES_PASSWORD=influenza123 `
  -e POSTGRES_DB=influenza_db `
  -p 5432:5432 `
  -v postgres_data:/var/lib/postgresql/data `
  -d postgres:15
```

This creates a "volume" that persists even if the container is removed.

## Common Docker Commands Cheat Sheet

```powershell
# List running containers
docker ps

# List all containers
docker ps -a

# View logs
docker logs <container-name>

# Stop container
docker stop <container-name>

# Start container
docker start <container-name>

# Remove container
docker rm <container-name>

# Execute command in container
docker exec <container-name> <command>

# Interactive shell in container
docker exec -it <container-name> bash

# Remove all stopped containers
docker container prune

# View Docker images
docker images

# Remove unused images
docker image prune
```

## Troubleshooting

**Container won't start?**
```powershell
# Check logs
docker logs influenza-postgres

# Check if port is already in use
netstat -an | findstr 5432
```

**Can't connect?**
- Make sure container is running: `docker ps`
- Check port mapping: `-p 5432:5432`
- Check firewall settings

**Want to start fresh?**
```powershell
docker stop influenza-postgres
docker rm influenza-postgres
# Then run docker run command again
```
