@echo off
echo 🚀 === CRM System Frontend Startup ===
echo.

echo 📦 Installing frontend dependencies...
cd frontend
if not exist "node_modules" (
    echo Installing React dependencies...
    call npm install
    if %errorlevel% neq 0 (
        echo ❌ Failed to install dependencies
        pause
        exit /b 1
    )
)

echo ⚡ Starting Frontend Development Server...
echo ✅ Frontend will be available at: http://localhost:3000
echo 🎨 React + TypeScript + Material-UI
echo 📱 Responsive design for all devices
echo.
echo 🔗 Make sure backend is running on port 3001
echo    Run start-backend.bat first if not running
echo.

call npm run dev

pause