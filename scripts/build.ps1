$ErrorActionPreference = "Stop"

Write-Host "==> Rust version"
rustc -Vv
cargo -V

Write-Host "==> Flutter version"
flutter --version

Write-Host "==> Enable Windows desktop"
flutter config --enable-windows-desktop

Write-Host "==> Fetch dependencies"
flutter pub get

Write-Host "==> Build Rust"
cargo build --release

Write-Host "==> Build Flutter Windows"
flutter build windows --release

Write-Host "==> Build completed"
