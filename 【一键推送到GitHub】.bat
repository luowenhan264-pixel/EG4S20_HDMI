@echo off
chcp 65001 >nul
title 正在推送到 GitHub...
cd /d "%~dp0"

echo =======================================================
echo    安路 EG4S20 HDMI 多媒体播放系统 - GitHub 一键同步工具
echo =======================================================
echo.
echo 目标仓库: https://github.com/luowenhan264-pixel/EG4S20_HDMI.git
echo 当前分支: main
echo.
echo 正在连接 GitHub 并推送最新代码，请稍候...
echo (若弹出浏览器登录窗口，请点击 [Sign in with your browser] 完成授权)
echo.

git push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo =======================================================
    echo   [成功] 代码已全部推送到 GitHub！
    echo   仓库主页: https://github.com/luowenhan264-pixel/EG4S20_HDMI
    echo =======================================================
) else (
    echo.
    echo =======================================================
    echo   [提示] 推送未完成，请检查是否在浏览器中登录了账号 luowenhan264-pixel。
    echo =======================================================
)

echo.
pause
