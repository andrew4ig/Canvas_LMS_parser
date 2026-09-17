def clean:
    tostring
  # HTML entities
  | gsub("&nbsp;?"; " ")
  | gsub("&amp;";   "&")
  | gsub("&lt;";    "<")
  | gsub("&gt;";    ">")
  | gsub("&quot;";  "\"")
  | gsub("&#39;";   "'")
  # any leftover tag (block-level → space, so words don't concatenate)
  | gsub("</?[[:alnum:]][^>]*>"; " ")
  # Collapse spaces/tabs/NBSP
  | gsub("[ \t\u00a0]+"; " ")
  # Newlines become <br>, then collapse runs
  | gsub("\r"; "")
  | gsub("\n"; "<br>")
  | gsub("(<br>[ ]*)+"; "<br>")
  | gsub("^(<br>)+"; "")
  | gsub("(<br>)+$"; "")
  # Literal "null" strings left by Canvas
  | gsub("\\bnull\\b"; "")
  # Trim outer whitespace
  | sub("^ +"; "")
  | sub(" +$"; "")
;