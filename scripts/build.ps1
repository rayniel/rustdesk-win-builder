$ErrorActionPreference = "Stop"

Write-Host "==> Rust version"
rustc -Vv
cargo -V

Write-Host "==> Python version"
python --version

Write-Host "==> Flutter version"
flutter --version

Write-Host "==> Enable Windows desktop"
flutter config --enable-windows-desktop

Write-Host "==> Build RustDesk Windows (Flutter)"
python .\build.py --portable --hwcodec --flutter --vram

Write-Host "==> Build completed"
