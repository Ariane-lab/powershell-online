#!/usr/bin/env bash
set -euo pipefail
mkdir -p out
pwsh ./find-bornes.ps1 -MonumentsCsv monuments.csv -IrveCsv irve.csv -OutCsv out/bornes_50kW_dans_500m.csv -OutHtml out/carte_monuments_x_bornes.html
echo "Outputs written to ./out/"
