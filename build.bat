@echo off
zig build -Doptimize=ReleaseFast
if %errorlevel% neq 0 (
    echo Build failed!
    exit /b %errorlevel%
)

if not exist bin mkdir bin
copy /y zig-out\bin\wmpartinfo.exe bin\wmpartinfo.exe
copy /y zig-out\bin\wmnkextract.exe bin\wmnkextract.exe

echo Build successful! Binaries placed in bin/
