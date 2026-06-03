@echo off
set ODIN="C:\Users\devdo\gamedevW\Documents\Odin\dist\odin.exe"
set SRC=%~dp0
set OUT=%SRC%SoulBinder.exe

%ODIN% build "%SRC%" -out:"%OUT%" -o:none 2>&1 && (
    echo Build successful: %OUT%
) || (
    echo Build failed.
    exit /b 1
)
