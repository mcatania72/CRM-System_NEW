@echo off
echo 🚀 === CRM System Backend Startup ===
echo.

echo 📦 Installing backend dependencies...
cd backend
if not exist "node_modules" (
    echo Installing dependencies...
    call npm install
    if %errorlevel% neq 0 (
        echo ❌ Failed to install dependencies
        pause
        exit /b 1
    )
)

echo ⚡ Starting Backend Server on port 3001...
echo ✅ Backend will be available at: http://localhost:3001
echo 🔧 API Health Check: http://localhost:3001/api/health
echo 🔐 Login endpoint: http://localhost:3001/api/auth/login
echo.
echo 🔑 Demo credentials:
echo    Email: admin@crm.local
echo    Password: admin123
echo.

start "CRM Backend Server" cmd /k "npm run dev"

echo ✅ Backend started successfully!
echo 📊 Open http://localhost:3001 to test the server
echo.
pause