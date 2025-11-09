# Requires: PowerShell 5+
# Env:
#   STRAPI_TOKEN (opcional)
#   STRAPI_BASE_URL (default: http://localhost:1337)
#   SOURCE_API_URL (default: https://dragonball-api.com/api/transformations)

$ErrorActionPreference = 'Stop'

$STRAPI_TOKEN = $env:STRAPI_TOKEN
$STRAPI_BASE_URL = if ($env:STRAPI_BASE_URL) { $env:STRAPI_BASE_URL } else { 'http://localhost:1337' }
$SOURCE_API_URL = if ($env:SOURCE_API_URL) { $env:SOURCE_API_URL } else { 'https://dragonball-api.com/api/transformations' }

function Get-AllSourceItems {
  param([string]$StartUrl)
  Write-Host "Fetching: $StartUrl"
  $resp = Invoke-RestMethod -Method GET -Uri $StartUrl
  if ($resp -is [System.Array]) { return $resp }
  if ($resp.items) { return $resp.items }
  if ($resp.transformations) { return $resp.transformations }
  return @($resp)
}

function Map-SourceToStrapiData {
  param($item)
  $tName = $null
  if ($item -ne $null) {
    if ($item.name) { $tName = $item.name }
    elseif ($item['name']) { $tName = $item['name'] }
    elseif ($item.transformation) { $tName = $item.transformation }
    elseif ($item['transformation']) { $tName = $item['transformation'] }
    elseif ($item.title) { $tName = $item.title }
    elseif ($item['title']) { $tName = $item['title'] }
    elseif ($item.label) { $tName = $item.label }
    elseif ($item['label']) { $tName = $item['label'] }
  }

  $tKi = $null
  if ($item -ne $null) {
    if ($item.ki) { $tKi = $item.ki }
    elseif ($item['ki']) { $tKi = $item['ki'] }
    elseif ($item.power) { $tKi = $item.power }
    elseif ($item['power']) { $tKi = $item['power'] }
    elseif ($item.level) { $tKi = $item.level }
    elseif ($item['level']) { $tKi = $item['level'] }
  }

  if ($tName -is [string]) { $tName = $tName.Trim() }

  return [pscustomobject]@{
    name = $tName
    ki   = $tKi
    # image skip (media upload no incluido)
  }
}

function Find-TransformationIdByName {
  param([string]$name)
  $uri = "$STRAPI_BASE_URL/api/transformations?filters[name][$eqi]=$( [uri]::EscapeDataString($name) )&pagination[pageSize]=1"
  $headers = @{}
  if ($STRAPI_TOKEN) { $headers.Authorization = "Bearer $STRAPI_TOKEN" }
  $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
  if ($resp.data -and $resp.data.Count -gt 0) { return $resp.data[0].id }
  return $null
}

function Create-Transformation {
  param($data)
  $body = @{ data = $data } | ConvertTo-Json -Depth 5
  $headers = @{ 'Content-Type' = 'application/json' }
  if ($STRAPI_TOKEN) { $headers.Authorization = "Bearer $STRAPI_TOKEN" }
  return Invoke-RestMethod -Method POST -Uri "$STRAPI_BASE_URL/api/transformations" -Headers $headers -Body $body
}

function Update-Transformation {
  param([int]$id, $data)
  $body = @{ data = $data } | ConvertTo-Json -Depth 5
  $headers = @{ 'Content-Type' = 'application/json' }
  if ($STRAPI_TOKEN) { $headers.Authorization = "Bearer $STRAPI_TOKEN" }
  return Invoke-RestMethod -Method PUT -Uri "$STRAPI_BASE_URL/api/transformations/$id" -Headers $headers -Body $body
}

Write-Host "Source: $SOURCE_API_URL"
Write-Host "Strapi: $STRAPI_BASE_URL"

$items = Get-AllSourceItems -StartUrl $SOURCE_API_URL
Write-Host ("Total fetched: {0}" -f $items.Count)

$created = 0; $updated = 0; $skipped = 0
$skipLogged = 0

foreach ($it in $items) {
  try {
    $data = Map-SourceToStrapiData -item $it
    if (-not $data.name) {
      $typeName = if ($it -ne $null) { $it.GetType().FullName } else { 'null' }
      $keys = ''
      if ($it -is [System.Collections.IDictionary]) { $keys = ($it.Keys | ForEach-Object { $_ }) -join ', ' }
      elseif ($it -and $it.PSObject -and $it.PSObject.Properties) { $keys = ($it.PSObject.Properties | ForEach-Object { $_.Name }) -join ', ' }
      Write-Warning ("Skipped item without name. Type: {0}. Keys: {1}" -f $typeName, $keys)
      if ($skipLogged -lt 3) {
        try {
          $json = $it | ConvertTo-Json -Depth 5 -Compress
          Write-Warning ("Sample skipped JSON: {0}" -f $json)
        } catch {}
        $skipLogged++
      }
      $skipped++; continue
    }

    $existingId = Find-TransformationIdByName -name $data.name
    if ($existingId) {
      [void](Update-Transformation -id $existingId -data $data)
      $updated++
    } else {
      [void](Create-Transformation -data $data)
      $created++
    }
  } catch {
    $nameForLog = if ($it.name) { $it.name } else { '(no-name)' }
    Write-Warning ("Failed for {0}: {1}" -f $nameForLog, $_.Exception.Message)
  }
}

Write-Host ("Done. Created: {0}, Updated: {1}, Skipped: {2}" -f $created, $updated, $skipped)


