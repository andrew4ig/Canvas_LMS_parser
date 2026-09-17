# Canvas LMS → PDF pipeline (Skoltech)

Automates downloading Canvas (Skoltech LMS) submissions, converting them to
anonymised or named PDFs, and emailing them via SMTP.

## Pipeline

```
script.sh ──► per_day.sh ──► download_from_canvas.sh   (fetch JSON via API)
                          ├► txt_to_pdf.sh             (build HTML + render PDF)
                          └► send_mail.sh              (SMTP via msmtp)
```

`txt_to_pdf.sh` uses `render_pdf.py`, a small WeasyPrint wrapper that measures
the content and produces a **single-page PDF whose height matches the content
exactly** (no white space at the bottom).

## Requirements

| Tool        | Purpose                                     |
|-------------|---------------------------------------------|
| `bash`      | scripts                                     |
| `curl`      | API calls                                   |
| `jq`        | JSON parsing                                |
| `python3`   | runs `render_pdf.py`                        |
| `weasyprint`| HTML → PDF (`pip install weasyprint`)       |
| `msmtp`     | sending email                               |

On macOS the default `bash` (3.2) works; use `brew install jq weasyprint msmtp`.

### Fonts / macOS

The HTML deliberately uses a **system font stack** (`-apple-system`, Helvetica,
Arial). If you swap in a webfont or Google Fonts `<link>`, WeasyPrint will
fetch the file at render time and you may see Fontconfig warnings such as:

```
Fontconfig error: the ambiguous constant name: normal ...
fsSelection bit 5 (bold) and head table macStyle bit 0 (bold) should match
```

Those warnings come from the *font file*, not from this project — avoid the
offending font (Roboto is a common culprit on macOS) and use a numeric
`font-weight` (400 / 700) instead of `normal` / `bolder`.

## Cron

Run every weekday at 23:59:

```cron
59 23 * * 1-5 /path/to/Canvas_LMS_parser/script.sh >> /path/to/Canvas_LMS_parser/cron.log 2>&1
```

## Data files

**`dates_HWid.txt`, `dates_MUDCARDid.txt`**

```
%Y_%m_%d    id
2025_07_01  28855
2025_07_02  28913
2025_07_03  28916
```

**`.info`** — API token, course, and email routing:

```text
token      YOUR_CANVAS_API_TOKEN
COURSE_ID  1234
sender     mail@example.com
recipents  inbox1@mail.ru inbox2@skoltech.ru
```

**`.msmtprc`** — SMTP config (*`chmod 600 .msmtprc`*):

```text
account default
auth            plain
tls             on
tls_starttls    on
host            smtp.type.com
port            666
from            mail@mail.com
user            mail@mail.com
password        password
```