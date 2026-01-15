FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

WORKDIR /workspace

# copy files into container
COPY . /workspace

# Make script executable (not necessary but nice)
RUN chmod +x ./find-bornes.ps1

# Default command simply prints usage; you can override to run the script
CMD ["pwsh", "-NoLogo", "-NoProfile", "-Command", "Write-Host 'Run: pwsh ./find-bornes.ps1 -MonumentsCsv monuments.csv -IrveCsv irve.csv -OutCsv out/bornes.csv -OutHtml out/map.html'"]
