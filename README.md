# Find bornes near monuments (PowerShell)

This repository contains a PowerShell script that finds EV chargers (IRVE) with power >= MinPowerKw within RadiusMeters of monuments, exports a CSV and an interactive Leaflet HTML map.

Files:
- `find-bornes.ps1` — main script (PowerShell)
- `monuments.csv`, `irve.csv` — example data
- `Dockerfile` — container with PowerShell to run the script
- `run.sh` — helper to run the script inside a container or locally with pwsh

Options to run:

## 1) Run locally (Windows or Linux/macOS with PowerShell 7+)
- Install PowerShell 7+ if not already: https://learn.microsoft.com/powershell/scripting/install/installing-powershell
- From repo folder:
  - Make output dir: `mkdir out`
  - Run:
    - Windows PowerShell:
      pwsh.exe ./find-bornes.ps1 -MonumentsCsv monuments.csv -IrveCsv irve.csv -OutCsv out/bornes_50kW_dans_500m.csv -OutHtml out/carte_monuments_x_bornes.html
    - Linux/macOS (pwsh):
      ./run.sh

## 2) Run with Docker (recommended if you don't want to install PowerShell)
- Build:
  docker build -t bornes .
- Run:
  docker run --rm -v "$(pwd)/out:/workspace/out" bornes pwsh ./find-bornes.ps1 -MonumentsCsv monuments.csv -IrveCsv irve.csv -OutCsv out/bornes_50kW_dans_500m.csv -OutHtml out/carte_monuments_x_bornes.html
- Result files in `./out/`

## 3) Run in the cloud via Gitpod (one-click)
1. Push this repo to GitHub.
2. Open in Gitpod by replacing `<your-repo-url>`:
   https://gitpod.io#<your-repo-url>
3. In the Gitpod terminal:
   pwsh ./find-bornes.ps1 -MonumentsCsv monuments.csv -IrveCsv irve.csv -OutCsv out/bornes_50kW_dans_500m.csv -OutHtml out/carte_monuments_x_bornes.html
4. You can preview `out/carte_monuments_x_bornes.html` in the Gitpod browser preview.

## 4) GitHub Codespaces
- Add the devcontainer (provided) to your repo and open in Codespaces. Once started, run the `pwsh` command as above.

Notes:
- If your IRVE CSV uses different column names for latitude/longitude/power, edit the variables near the top of `find-bornes.ps1`:
  `$IrveLatCol`, `$IrveLonCol`, `$IrvePwrCol`
- For large IRVE datasets (>>10k rows) consider pre-tiling or indexing; the script uses brute-force pairwise checking.

If you want, I can:
- Create the GitHub repo for you (you'll need to give me permission to push or provide a repo name).
- Provide a one-click Gitpod URL once the repo exists.
- Modify the script to match your real CSV column names if you paste a sample of the real headers.
