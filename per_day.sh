#!/bin/bash

bash ./download_from_canvas.sh $1 $2 $3
bash ./txt_to_pdf.sh $1 $2 $3
bash ./send_mail.sh $1 $2 $3