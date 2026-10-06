# Starts the Rails server and the Vite dev server together, for Windows, where
# bin/dev (foreman) does not work. Stop both with Ctrl+C.
#
#   .\bin\dev.ps1            # http://localhost:3000
#   .\bin\dev.ps1 -Port 4000
param([int]$Port = 3000)

Set-Location (Split-Path $PSScriptRoot -Parent)

$vite = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "npx vite" -PassThru -NoNewWindow

try {
  ruby bin/rails server -p $Port
}
finally {
  # Vite runs under cmd.exe, so stop the whole tree.
  taskkill /PID $vite.Id /T /F | Out-Null
}
