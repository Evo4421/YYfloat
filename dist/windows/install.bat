@echo on
setlocal enabledelayedexpansion

set "APP_NAME=yyfloat"
set "ROOT_DIR=%USERPROFILE%\.yyfloat"
set "PAK_NAME=yyfloat.exe"

if not exist "%ROOT_DIR%" (
    mkdir "%ROOT_DIR%"
)

echo [*] 启动安装 %APP_NAME%
curl -L -o "%ROOT_DIR\%PAK_NAME" "https://evo-blog-by-linghan.eu.cc:10406/downloads/yyfloat-x86_64-windows"

if errorlevel 1 (
    echo [*] 下载失败!
    pause
    exit /b 1
)

echo [*] 下载完成,位置: %ROOT_DIR%\%PAK_NAME%

for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USER_PATH=%%B"

echo !USER_PATH! | find /i "%ROOT_DIR%" >nul
if errorlevel 1 (
    if defined USER_PATH (
        setx PATH "!USER_PATH!;%ROOT_DIR%" >nul
    ) else (
        setx PATH "%ROOT_DIR%" >nul
    )
) else (
    echo [*] 配置项已包含,跳过
)

set "PATH=%PATH%;%ROOT_DIR%"

echo.
echo [*] 安装成功!
echo [*] 如何使用: 重新打开命令提示符,输入yyfloat --help查看帮助
echo [*] 以后想使用,都可以直接在命令提示符输入yyfloat直接打开

pause
endlocal