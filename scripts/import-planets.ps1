# Requires: PowerShell 5+
# Env:
#   STRAPI_TOKEN (opcional)
#   STRAPI_BASE_URL (default: http://localhost:1337)
#   SOURCE_API_URL (default: https://dragonball-api.com/api/planets)

$ErrorActionPreference = 'Stop'

$STRAPI_TOKEN = $env:STRAPI_TOKEN
$STRAPI_BASE_URL = if ($env:STRAPI_BASE_URL) { $env:STRAPI_BASE_URL } else { 'http://localhost:1337' }
$SOURCE_API_URL = if ($env:SOURCE_API_URL) { $env:SOURCE_API_URL } else { 'https://dragonball-api.com/api/planets' }

function Get-AllSourceItems {
  param([string]$StartUrl)
  $all = @()
  $url = $StartUrl
  while ($url) {
    Write-Host "Fetching: $url"
    $resp = Invoke-RestMethod -Method GET -Uri $url
    $pageItems = @()
    if ($resp.items) { $pageItems = $resp.items }
    elseif ($resp.planets) { $pageItems = $resp.planets }
    elseif ($resp -is [System.Collections.IEnumerable]) { $pageItems = $resp }
    $all += $pageItems
    $next = $null
    if ($resp.links -and $resp.links.next) { $next = $resp.links.next }
    $url = $next
  }
  return $all
}

function Map-SourceToStrapiData {
  param($item)
  return [pscustomobject]@{
    name        = $item.name
    isDestroyed = if ($item.isDestroyed -ne $null) { [bool]$item.isDestroyed } else { $null }
    description = $item.description
  }
}

function Find-PlanetIdByName {
  param([string]$name)
  $uri = "$STRAPI_BASE_URL/api/planets?filters[name][$eqi]=$( [uri]::EscapeDataString($name) )&pagination[pageSize]=1"
  $headers = @{}
  if ($STRAPI_TOKEN) { $headers.Authorization = "Bearer $STRAPI_TOKEN" }
  $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
  if ($resp.data -and $resp.data.Count -gt 0) { return $resp.data[0].id }
  return $null
}

function Create-Planet {
  param($data)
  $body = @{ data = $data } | ConvertTo-Json -Depth 5
  $headers = @{ 'Content-Type' = 'application/json' }
  if ($STRAPI_TOKEN) { $headers.Authorization = "Bearer $STRAPI_TOKEN" }
  return Invoke-RestMethod -Method POST -Uri "$STRAPI_BASE_URL/api/planets" -Headers $headers -Body $body
}

function Update-Planet {
  param([int]$id, $data)
  $body = @{ data = $data } | ConvertTo-Json -Depth 5
  $headers = @{ 'Content-Type' = 'application/json' }
  if ($STRAPI_TOKEN) { $headers.Authorization = "Bearer $STRAPI_TOKEN" }
  return Invoke-RestMethod -Method PUT -Uri "$STRAPI_BASE_URL/api/planets/$id" -Headers $headers -Body $body
}

Write-Host "Source: $SOURCE_API_URL"
Write-Host "Strapi: $STRAPI_BASE_URL"

$items = Get-AllSourceItems -StartUrl $SOURCE_API_URL
Write-Host ("Total fetched: {0}" -f $items.Count)

$created = 0; $updated = 0; $skipped = 0

foreach ($it in $items) {
  try {
    $data = Map-SourceToStrapiData -item $it
    if (-not $data.name) { $skipped++; continue }

    $existingId = Find-PlanetIdByName -name $data.name
    if ($existingId) {
      [void](Update-Planet -id $existingId -data $data)
      $updated++
    } else {
      [void](Create-Planet -data $data)
      $created++
    }
  } catch {
    $nameForLog = if ($it.name) { $it.name } else { '(no-name)' }
    Write-Warning ("Failed for {0}: {1}" -f $nameForLog, $_.Exception.Message)
  }
}

Write-Host ("Done. Created: {0}, Updated: {1}, Skipped: {2}" -f $created, $updated, $skipped)


