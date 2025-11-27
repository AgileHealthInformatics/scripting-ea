param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$OutDir
)

function New-Slug([string]$s){ $t=$s.ToLower() -replace '[^a-z0-9]+','-' -replace '-+','-'; $t.Trim('-'); if(!$t){'untitled'}else{$t} }
function W([string]$p,[string[]]$L){ $e=New-Object System.Text.UTF8Encoding($false); [IO.File]::WriteAllText($p,($L -join "`n"),$e)}

if(!(Test-Path -LiteralPath $InputPath)){ throw "Not found: $InputPath" }
if(!(Test-Path -LiteralPath $OutDir)){ New-Item -ItemType Directory -Path $OutDir | Out-Null }

$text  = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8
$text  = ($text -replace "`r`n","`n") -replace "`r","`n"
$lines = $text -split "`n"

$chapters = @()
$currentTitle = $null
$currentBuf = New-Object System.Collections.Generic.List[string]
$h1 = '^\#\s(?!\#)(.+)$'

function Flush([string]$title,[System.Collections.Generic.List[string]]$buf,[int]$i){
  if([string]::IsNullOrWhiteSpace($title) -or $buf.Count -eq 0){ return $null }
  if($title.Trim() -eq 'Contents'){ return $null }
  $file = ('{0:D2}-{1}.qmd' -f $i, (New-Slug $title))
  W $file $buf
  Write-Host "Wrote chapter: $file"
  return $file
}

# Ensure index.qmd
if(!(Test-Path 'index.qmd')){
  W 'index.qmd' @('---','title: "Scripting Sparx Enterprise Architect: A Practical Handbook"','format:','  html:','    toc: false','---','','# Welcome','','This is the web edition of *Scripting Sparx Enterprise Architect*. Use the left navigation to browse chapters.')
  Write-Host 'Created index.qmd'
}

foreach($line in $lines){
  $m=[regex]::Match($line,$h1)
  if($m.Success){
    if($currentTitle){
      $f = Flush $currentTitle $currentBuf ($chapters.Count+1); if($f){ $chapters += $f }
    }
    $currentTitle = $m.Groups[1].Value.Trim()
    $currentBuf = New-Object System.Collections.Generic.List[string]
    $currentBuf.Add($line) # keep the H1
  } else {
    $currentBuf.Add($line)
  }
}
if($currentTitle){
  $f = Flush $currentTitle $currentBuf ($chapters.Count+1); if($f){ $chapters += $f }
}

# YAML snippet
$yml = @(
'project:','  type: book','  output-dir: docs','',
'book:','  title: "Scripting Sparx Enterprise Architect: A Practical Handbook"',
'  author: "Tito Castillo"','  date: "2025"','  chapters:','    - index.qmd'
)
foreach($c in $chapters){ $yml += '    - ' + $c }
$yml += @('','format:','  html:','    theme: cosmo','    toc-depth: 3','    code-copy: true','    code-line-numbers: true')
W '_quarto-chapters.yml' $yml
Write-Host "Wrote YAML snippet: _quarto-chapters.yml"
