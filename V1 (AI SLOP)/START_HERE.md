# 🚀 Start Here - Docker Learning Path

## Quick Start (3 Steps)

### Step 1: Start Docker Desktop

**Option A: From Start Menu**
1. Press `Win` key
2. Type "Docker Desktop"
3. Click to open
4. Wait for it to fully start (whale icon appears in system tray)

**Option B: From PowerShell**
```powershell
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

**Wait for:** The whale icon in your system tray to stop animating (usually 30-60 seconds)

### Step 2: Run Setup Script

Once Docker Desktop is running, execute:

```powershell
.\setup_docker_postgres.ps1
```

This script will:
- ✅ Check Docker is running
- ✅ Create PostgreSQL container
- ✅ Test the connection
- ✅ Set environment variables
- ✅ Explain what each step does

### Step 3: Create Database Tables

```powershell
python create_tables.py
```

This creates all the tables you need automatically.

### Step 4: Test Google Trends Ingestion

```powershell
python run_google_trends_test.py
```

## What You'll Learn

By following this path, you'll learn:

1. **Docker Basics**
   - What containers are
   - How to create and manage them
   - Port mapping concepts
   - Environment variables

2. **Database Concepts**
   - PostgreSQL setup
   - Connection strings
   - Schema creation
   - Table management

3. **Data Engineering**
   - ETL pipeline execution
   - Data ingestion
   - Error handling
   - Logging

## Troubleshooting

### "Docker Desktop is not running"
- Open Docker Desktop from Start menu
- Wait for whale icon to appear in system tray
- Icon should be steady (not animating)

### "Port 5432 already in use"
- Another PostgreSQL instance might be running
- Check: `netstat -an | findstr 5432`
- Stop other PostgreSQL services if needed

### "Container already exists"
- The script will handle this automatically
- It will start the existing container

## Learning Resources

After setup, read:
- `DOCKER_LEARNING_GUIDE.md` - Detailed Docker explanations
- `QUICK_START.md` - Quick reference commands

## Ready?

1. **Start Docker Desktop** (wait for it to fully load)
2. **Run:** `.\setup_docker_postgres.ps1`
3. **Follow the prompts!**

Let me know when Docker Desktop is running and I'll help you execute the setup!
