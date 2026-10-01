# Builds the Spanish (/es/) and French (/fr/) sites from the English pages.
#
#   powershell -ExecutionPolicy Bypass -File tools/i18n.ps1 extract
#       Writes tools/i18n/en.tsv: every translatable string on the English
#       pages, keyed by a short hash of its text.
#
#   powershell -ExecutionPolicy Bypass -File tools/i18n.ps1 build
#       Regenerates es/*.html and fr/*.html from the English pages plus
#       tools/i18n/es.tsv and fr.tsv ("key<TAB>translation" per line), adds
#       the language switcher and hreflang links to every page, then rebuilds
#       the FAQ structured data. Strings with no translation stay in English
#       and are listed, so a changed English sentence is easy to spot.
#
# English stays the source of truth: edit the English page, run extract to
# see new keys, add their translations to es.tsv / fr.tsv, run build.
# Text between <!-- i18n:skip --> markers (customer reviews) is left as is.
param([ValidateSet('extract', 'build')][string]$Mode = 'build')
$ErrorActionPreference = 'Stop'

$root  = Split-Path $PSScriptRoot -Parent
$dir   = Join-Path $PSScriptRoot 'i18n'
$site  = 'https://www.thediversboat-kohphangan.com'
$pages = 'index.html', 'experiences.html', 'courses.html', 'dive-sites.html', 'about.html', 'gallery.html', 'ssi-open-water-course.html', 'sail-rock-diving-guide.html', 'whale-sharks-koh-phangan.html', 'ssi-advanced-open-water-course.html', 'ssi-deep-nitrox-courses.html', 'ssi-rescue-diver-course.html', 'ssi-divemaster-course.html', 'diving-health-safety.html', 'marine-life-koh-phangan.html', 'koh-phangan-vs-koh-tao-diving.html', 'guides.html'
$langs = [ordered]@{ en = 'EN'; es = 'ES'; fr = 'FR' }
$locales = @{ en = 'en_GB'; es = 'es_ES'; fr = 'fr_FR' }
$utf8  = New-Object Text.UTF8Encoding $false
$sep   = [string][char]1
$md5   = [Security.Cryptography.MD5]::Create()

function Norm([string]$s) { [regex]::Replace($s, '\s+', ' ').Trim() }
function Key([string]$s) {
  (($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($s)) | Select-Object -First 4 |
    ForEach-Object { $_.ToString('x2') }) -join '')
}
function Wanted([string]$s) { $s -match '\p{L}{2}' }
function PageUrl([string]$lang, [string]$page) {
  $path = if ($page -eq 'index.html') { '' } else { $page }
  if ($lang -eq 'en') { "$site/$path" } else { "$site/$lang/$path" }
}
function RelLink([string]$from, [string]$to, [string]$page) {
  if ($from -eq $to) { return $page }
  if ($from -eq 'en') { return "$to/$page" }
  if ($to -eq 'en')   { return "../$page" }
  "../$to/$page"
}

# ---------------------------------------------------------------------------
# Chrome shared by every language: hreflang links, og:locale, the switcher.
# Each lives between markers so a rebuild replaces rather than duplicates.
# ---------------------------------------------------------------------------
function Set-Block([string]$html, [string]$name, [string]$block, [string]$anchor, [switch]$Before) {
  $re = "(?s)\s*<!-- i18n:$name -->.*?<!-- /i18n:$name -->"
  $html = [regex]::Replace($html, $re, '')
  $wrapped = "<!-- i18n:$name -->$block<!-- /i18n:$name -->"
  $i = $html.IndexOf($anchor)
  if ($i -lt 0) { throw "anchor '$anchor' not found for $name" }
  if ($Before) { return $html.Insert($i, "$wrapped`n") }
  $j = $i + $anchor.Length
  $html.Insert($j, "`n$wrapped")
}

function Add-Chrome([string]$html, [string]$page, [string]$lang) {
  $alt = ($langs.Keys | ForEach-Object {
      "`n<link rel=`"alternate`" hreflang=`"$_`" href=`"$(PageUrl $_ $page)`">" }) -join ''
  $alt += "`n<link rel=`"alternate`" hreflang=`"x-default`" href=`"$(PageUrl 'en' $page)`">"
  $alt += "`n<meta property=`"og:locale`" content=`"$($locales[$lang])`">`n"
  $canon = [regex]::Match($html, '<link rel="canonical"[^>]*>').Value
  $html = Set-Block $html 'alt' $alt $canon

  $links = ($langs.Keys | ForEach-Object {
      $cur = if ($_ -eq $lang) { ' aria-current="true"' } else { '' }
      "<a href=`"$(RelLink $lang $_ $page)`" hreflang=`"$_`" lang=`"$_`"$cur>$($langs[$_])</a>" }) -join ''
  $html = Set-Block $html 'lang' "<div class=`"lang`" role=`"group`" aria-label=`"Language`">$links</div>" '</nav>'
  $html = Set-Block $html 'lang-drawer' "<div class=`"lang lang--drawer`" role=`"group`" aria-label=`"Language`">$links</div>" '<div class="drawer__foot">' -Before
  $html
}

# ---------------------------------------------------------------------------
# Walk the translatable parts of a page, calling $fn(normalisedText) for each
# and substituting whatever it returns.
# ---------------------------------------------------------------------------
function Map-Page([string]$html, [scriptblock]$fn) {
  $vault = New-Object System.Collections.Generic.List[string]
  $stash = { param($m) $vault.Add($m.Value); "$sep$($vault.Count - 1)$sep" }

  # JSON-LD (not the generated FAQ, which is rebuilt from the visible text)
  $html = [regex]::Replace($html, '(?s)<script type="application/ld\+json">.*?</script>', {
      param($m)
      [regex]::Replace($m.Value, '("(?:name|headline|description|jobTitle)":\s*")((?:[^"\\]|\\.)*)(")', {
          param($j)
          $raw = $j.Groups[2].Value.Replace('\"', '"')
          $n = Norm $raw
          if (-not (Wanted $n)) { return $j.Value }
          $out = (& $fn $n).Replace('"', '\"')
          $j.Groups[1].Value + $out + $j.Groups[3].Value
        })
    })

  $html = [regex]::Replace($html,
    '(?s)<!-- i18n:skip -->.*?<!-- /i18n:skip -->|<!--.*?-->|<script\b.*?</script>|<style\b.*?</style>|<svg\b.*?</svg>',
    [Text.RegularExpressions.MatchEvaluator]{ param($m) & $stash $m })

  # attributes
  $html = [regex]::Replace($html, '<[a-zA-Z][^>]*>', {
      param($t)
      $tag = $t.Value
      $tag = [regex]::Replace($tag, '(\s(?:alt|title|aria-label|placeholder|data-zone)=")([^"]*)(")', {
          param($a)
          $n = Norm $a.Groups[2].Value
          if (-not (Wanted $n)) { return $a.Value }
          $a.Groups[1].Value + (& $fn $n) + $a.Groups[3].Value
        })
      if ($tag -match '^<meta\s+(name="description"|property="og:(title|description)")') {
        $tag = [regex]::Replace($tag, '(\scontent=")([^"]*)(")', {
            param($a)
            $a.Groups[1].Value + (& $fn (Norm $a.Groups[2].Value)) + $a.Groups[3].Value
          })
      }
      $tag
    })

  # text between tags
  $html = [regex]::Replace($html, '>([^<]+)<', {
      param($m)
      # an icon (stashed <svg>) can sit beside the words: translate around it
      $parts = [regex]::Split($m.Groups[1].Value, "($sep\d+$sep)")
      $out = foreach ($text in $parts) {
        $n = Norm $text
        if ($text.Contains($sep) -or -not (Wanted $n)) { $text; continue }
        $lead  = [regex]::Match($text, '^\s*').Value
        $trail = [regex]::Match($text, '\s*$').Value
        $lead + (& $fn $n) + $trail
      }
      '>' + ($out -join '') + '<'
    })

  [regex]::Replace($html, "$sep(\d+)$sep", { param($m) $vault[[int]$m.Groups[1].Value] })
}

function Read-Tsv([string]$path) {
  $map = @{}
  if (-not (Test-Path $path)) { return $map }
  foreach ($line in [IO.File]::ReadAllLines($path, $utf8)) {
    if ($line -match '^([0-9a-f]{8})\s+(.*\S)\s*$') { $map[$Matches[1]] = $Matches[2] }
  }
  $map
}

# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force $dir | Out-Null

# English pages get the chrome too, and are the source for everything else.
$source = @{}
foreach ($page in $pages) {
  $p = Join-Path $root $page
  $html = Add-Chrome ([IO.File]::ReadAllText($p, $utf8)) $page 'en'
  [IO.File]::WriteAllText($p, $html, $utf8)
  $source[$page] = $html
}

if ($Mode -eq 'extract') {
  $seen = [ordered]@{}
  foreach ($page in $pages) {
    $null = Map-Page $source[$page] {
      param($n)
      $k = Key $n
      if (-not $seen.Contains($k)) { $seen[$k] = "$k`t$n`t$page" }
      $n
    }
  }
  [IO.File]::WriteAllLines((Join-Path $dir 'en.tsv'), [string[]]$seen.Values, $utf8)
  "en.tsv: $($seen.Count) strings"
  return
}

foreach ($lang in @($langs.Keys | Where-Object { $_ -ne 'en' })) {
  $dict = Read-Tsv (Join-Path $dir "$lang.tsv")
  $missing = [ordered]@{}
  $out = Join-Path $root $lang
  New-Item -ItemType Directory -Force $out | Out-Null

  foreach ($page in $pages) {
    $html = $source[$page]
    $html = [regex]::Replace($html, '(?s)\s*<script type="application/ld\+json" data-faq>.*?</script>', '')
    $html = Map-Page $html {
      param($n)
      $k = Key $n
      if ($dict.ContainsKey($k)) { return $dict[$k] }
      $missing[$k] = $n
      $n
    }
    $html = $html.Replace('<html lang="en">', "<html lang=`"$lang`">")
    # assets sit one level up
    $html = [regex]::Replace($html, '(?<=[\s"'',])(assets/|favicon\.png|apple-touch-icon\.png)', '../$1')
    # this page's own address
    $html = [regex]::Replace($html, '(<link rel="canonical" href="|<meta property="og:url" content=")[^"]*',
      { param($m) $m.Groups[1].Value + (PageUrl $lang $page) })
    # structured-data links to pages (not the business's own homepage URL)
    $html = [regex]::Replace($html, '("(?:url|item)": ")' + [regex]::Escape($site) + '/([a-z-]*\.html(?:#[a-z-]+)?)?(")', {
        param($m)
        $path = $m.Groups[2].Value
        if (-not $path -and $m.Value -match '^"url"') { return $m.Value }
        $m.Groups[1].Value + "$site/$lang/$path" + $m.Groups[3].Value
      })
    $html = $html.Replace('"inLanguage": "en"', "`"inLanguage`": `"$lang`"")
    $html = Add-Chrome $html $page $lang
    [IO.File]::WriteAllText((Join-Path $out $page), $html, $utf8)
  }

  "{0}: {1} pages, {2} strings without translation" -f $lang, $pages.Count, $missing.Count
  $missing.GetEnumerator() | Select-Object -First 25 | ForEach-Object { "   $($_.Key)  $($_.Value)" }
}

& (Join-Path $PSScriptRoot 'sync-faq.ps1') | Out-Null
'FAQ structured data rebuilt'
