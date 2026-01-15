<#
Prereqs:
- PowerShell 5.1+ (Windows) or PowerShell 7+ (cross-platform)
Inputs:
- monuments.csv : name,lat,lon
- irve.csv      : colonnes lat/lon + puissance (voir variables ci-dessous)

Outputs:
- bornes_50kW_dans_500m.csv
- carte_monuments_x_bornes.html
#>

param(
  [Parameter(Mandatory=$false)][string]$MonumentsCsv = ".\monuments.csv",
  [Parameter(Mandatory=$false)][string]$IrveCsv      = ".\irve.csv",
  [Parameter(Mandatory=$false)][string]$OutCsv       = ".\bornes_50kW_dans_500m.csv",
  [Parameter(Mandatory=$false)][string]$OutHtml      = ".\carte_monuments_x_bornes.html",
  [Parameter(Mandatory=$false)][double]$MinPowerKw   = 50,
  [Parameter(Mandatory=$false)][double]$RadiusMeters = 500
)

# ==== ADAPTER ICI selon ton fichier IRVE ====
$IrveLatCol = "latitude"
$IrveLonCol = "longitude"
$IrvePwrCol = "puissance_nominale"   # ou puissance_nominale_kw, puissance, etc.
$IrveIdCol  = "id_pdc_itinerance"    # optionnel (si absent, laisse vide)
$IrveOpCol  = "nom_operateur"        # optionnel (si absent, laisse vide)
# ===========================================

function Get-HaversineMeters {
  param(
    [double]$Lat1, [double]$Lon1,
    [double]$Lat2, [double]$Lon2
  )
  $R = 6371000.0
  $dLat = ([math]::PI/180.0) * ($Lat2 - $Lat1)
  $dLon = ([math]::PI/180.0) * ($Lon2 - $Lon1)
  $a = [math]::Sin($dLat/2)*[math]::Sin($dLat/2) +
       [math]::Cos(([math]::PI/180.0)*$Lat1) * [math]::Cos(([math]::PI/180.0)*$Lat2) *
       [math]::Sin($dLon/2)*[math]::Sin($dLon/2)
  $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1-$a))
  return $R * $c
}

function To-JsonSafe([string]$s) {
  if ($null -eq $s) { return "" }
  return ($s -replace '\\','\\' -replace '"','\"' -replace "`r?`n"," ")
}

# --- Load monuments
if (-not (Test-Path $MonumentsCsv)) { throw "Monuments CSV not found: $MonumentsCsv" }
$monuments = Import-Csv -Path $MonumentsCsv

# Basic validation
foreach ($m in $monuments) {
  if (-not $m.name -or -not $m.lat -or -not $m.lon) {
    throw "monuments.csv must contain columns: name, lat, lon"
  }
}

# --- Load IRVE
if (-not (Test-Path $IrveCsv)) { throw "IRVE CSV not found: $IrveCsv" }
$irveAll = Import-Csv -Path $IrveCsv

# Ensure required columns exist
$cols = $irveAll[0].PSObject.Properties.Name
foreach ($c in @($IrveLatCol,$IrveLonCol,$IrvePwrCol)) {
  if ($cols -notcontains $c) {
    throw "IRVE CSV missing required column '$c'. Available: $($cols -join ', ')"
  }
}

# Filter power > MinPowerKw and valid coordinates
$irve = foreach ($r in $irveAll) {
  $lat = [double]::NaN
  $lon = [double]::NaN
  $pwr = [double]::NaN
  [void][double]::TryParse($r.$IrveLatCol, [ref]$lat)
  [void][double]::TryParse($r.$IrveLonCol, [ref]$lon)
  [void][double]::TryParse($r.$IrvePwrCol, [ref]$pwr)
  if ([double]::IsNaN($lat) -or [double]::IsNaN($lon) -or [double]::IsNaN($pwr)) { continue }
  if ($pwr -le $MinPowerKw) { continue }
  # keep record with parsed numbers attached
  $r | Add-Member -NotePropertyName "_lat" -NotePropertyValue $lat -Force
  $r | Add-Member -NotePropertyName "_lon" -NotePropertyValue $lon -Force
  $r | Add-Member -NotePropertyName "_pwr" -NotePropertyValue $pwr -Force
  $r
}

Write-Host "Monuments loaded : $($monuments.Count)"
Write-Host "IRVE filtered > $MinPowerKw kW : $($irve.Count)"

# --- Cross (brute-force). Works OK for a few 10k rows. For very large IRVE, pre-tile by bbox.
$hits = New-Object System.Collections.Generic.List[object]

foreach ($m in $monuments) {
  $mLat = [double]$m.lat
  $mLon = [double]$m.lon
  $mName = [string]$m.name

  foreach ($r in $irve) {
    $d = Get-HaversineMeters -Lat1 $mLat -Lon1 $mLon -Lat2 $r._lat -Lon2 $r._lon
    if ($d -le $RadiusMeters) {
      $obj = [pscustomobject]@{
        monument       = $mName
        monument_lat   = $mLat
        monument_lon   = $mLon
        distance_m     = [math]::Round($d,1)
        power_kw       = $r._pwr
        borne_lat      = $r._lat
        borne_lon      = $r._lon
        id_pdc         = $(if ($cols -contains $IrveIdCol) { $r.$IrveIdCol } else { "" })
        operateur      = $(if ($cols -contains $IrveOpCol) { $r.$IrveOpCol } else { "" })
      }
      $hits.Add($obj) | Out-Null
    }
  }
}

Write-Host "Hits found (<= $RadiusMeters m) : $($hits.Count)"

# --- Export CSV
$hits | Sort-Object monument, distance_m | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
Write-Host "CSV exported: $OutCsv"

# --- Build HTML Leaflet map
# Center France approx
$leafletCss = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
$leafletJs  = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"

# Prepare JS arrays
$monJs = ($monuments | ForEach-Object {
  '{name:"' + (To-JsonSafe $_.name) + '",lat:' + $_.lat + ',lon:' + $_.lon + '}'
}) -join ",`n"

$hitJs = ($hits | ForEach-Object {
  '{monument:"' + (To-JsonSafe $_.monument) + '",d:' + $_.distance_m + ',p:' + $_.power_kw +
  ',lat:' + $_.borne_lat + ',lon:' + $_.borne_lon + ',op:"' + (To-JsonSafe $_.operateur) + '"}'
}) -join ",`n"

$html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>Monuments x Bornes > $MinPowerKw kW (<= $RadiusMeters m)</title>
<link rel="stylesheet" href="$leafletCss"/>
<style>
    html, body { height: 100%; margin: 0; }
    #map { height: 100%; }
    .legend { position: absolute; z-index: 999; background: white; padding: 10px; margin: 10px; border-radius: 6px; box-shadow: 0 1px 4px rgba(0,0,0,0.3); font: 12px/1.4 Arial; }
</style>
</head>
<body>
<div class="legend">
<div><b>Monuments</b> (points)</div>
<div><b>Bornes</b> > $MinPowerKw kW dans $RadiusMeters m (points)</div>
<div>Résultats: $($hits.Count)</div>
</div>
<div id="map"></div>
<script src="$leafletJs"></script>
<script>
  const monuments = [
$monJs
  ];

  const hits = [
$hitJs
  ];

  const map = L.map('map').setView([46.7, 2.5], 6);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap contributors'
  }).addTo(map);

  // Monuments (blue)
  monuments.forEach(m => {
    L.circleMarker([m.lat, m.lon], {radius: 6}).bindPopup(m.name).addTo(map);
  });

  // Hits (red-ish default Leaflet marker by CircleMarker settings)
  hits.forEach(h => {
    const txt = `${h.monument}<br/>${h.p} kW<br/>${h.d} m<br/>${h.op || ''}`;
    L.circleMarker([h.lat, h.lon], {radius: 4}).bindPopup(txt).addTo(map);
  });
</script>
</body>
</html>
"@

Set-Content -Path $OutHtml -Value $html -Encoding UTF8
Write-Host "HTML map exported: $OutHtml"
