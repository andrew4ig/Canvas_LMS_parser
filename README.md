Scrip made for converting bunch of submissions from lms.canvas.skoltech to pdf for further sending via mail.

Pipeline of script.sh:
for given course_id - 5149 (# correct in download_from_canvas) according to the todays submissions (from date we can get assigments id from dates_HWid and dates_MUDCARDid) 
    Pipeline of per_day.sh:
    1) firsly submissions get downloaded with api using token in .token
    2) PDF is created (anonym or not anonym depends on the type of submission)
    3) PDF is sent with smtp using given .msmtprc config

Automatisation:
```
cron: 1 23 1-30 9 1-5 /script.sh [https://phoenixnap.com/kb/cron-job-mac]
```

```structure of dates_HWid and dates_MUDCARDid
%Y_%m_%d    id
%Y_%m_%d    id
2025_07_01  28855
2025_07_02  28913
2025_07_03  28916
```

```structure of .token
tokentokentokentokentokentokentokentokentokentokentokentokentokentokentoken
```

```structure of .msmtprc
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


# 1
Turns out there are anonymous (almost) quizes that prove anonymous free form submissions.

# 2
IT, need laptop or server for IW,  and SMTP mail.
