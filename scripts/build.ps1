param([string]$OutDir = "dist")

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast
Copy-Item "zig-out/bin/frag.dll" "$OutDir/frag.dll" -Force

zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
Copy-Item "zig-out/lib/libfrag.so" "$OutDir/libfrag.so" -Force

zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast
Copy-Item "zig-out/lib/libfrag.dylib" "$OutDir/libfrag.dylib" -Force

Write-Host "Done -> $OutDir"