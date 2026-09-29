# Rebuilds each page's FAQPage JSON-LD from the questions visible on the page,
# so the structured data can never drift from the text.
#
#   powershell -ExecutionPolicy Bypass -File tools/sync-faq.ps1
#
# Every page with a <div class="faq"> gets (or has replaced) one
# <script type="application/ld+json" data-faq> block before </head>.
param([string[]]$Pages)

$root = Split-Path $PSScriptRoot -Parent
if (-not $Pages) {
  $Pages = Get-ChildItem $root -Recurse -Filter *.html |
    Where-Object { $_.FullName -notmatch '\\(tools|\.claude|\.git)\\' } |
    ForEach-Object { $_.FullName }
}

function Clean([string]$s) {
  $s = [regex]::Replace($s, '<[^>]+>', '')
  $s = [System.Net.WebUtility]::HtmlDecode($s)
  $s = [regex]::Replace($s, '\s+', ' ').Trim()
  $s.Replace('\', '\\').Replace('"', '\"')
}

$utf8 = New-Object Text.UTF8Encoding $false

foreach ($page in $Pages) {
  $html = [IO.File]::ReadAllText($page)
  $faq  = [regex]::Match($html, '<div class="faq[^"]*"[^>]*>(.*?)</div>', 'Singleline')
  if (-not $faq.Success) { continue }

  $items = [regex]::Matches($faq.Groups[1].Value,
    '<details>\s*<summary>(.*?)</summary>\s*<p>(.*?)</p>\s*</details>', 'Singleline')
  if ($items.Count -eq 0) { continue }

  $entries = foreach ($m in $items) {
    '    { "@type": "Question", "name": "' + (Clean $m.Groups[1].Value) + '",' + "`n" +
    '      "acceptedAnswer": { "@type": "Answer", "text": "' + (Clean $m.Groups[2].Value) + '" } }'
  }
  $lang  = [regex]::Match($html, '<html lang="([^"]+)"').Groups[1].Value
  $block = "<script type=`"application/ld+json`" data-faq>`n{`n  `"@context`": `"https://schema.org`",`n" +
           "  `"@type`": `"FAQPage`",`n  `"inLanguage`": `"$lang`",`n  `"mainEntity`": [`n" +
           ($entries -join ",`n") + "`n  ]`n}`n</script>"

  if ($html -match '<script type="application/ld\+json" data-faq>') {
    $html = [regex]::Replace($html, '<script type="application/ld\+json" data-faq>.*?</script>',
      [System.Text.RegularExpressions.MatchEvaluator]{ param($x) $block }, 'Singleline')
  } else {
    $html = $html.Replace('</head>', "$block`n</head>")
  }
  [IO.File]::WriteAllText($page, $html, $utf8)
  "{0}: {1} questions" -f (Resolve-Path $page -Relative), $items.Count
}
