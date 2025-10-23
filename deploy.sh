#!/bin/bash 

# docker pull rstudio/plumber
docker build -t my-plumber-api .

docker run -it -p 8080:8000 my-plumber-api:latest /app/plumber2_ndjson.R

# sudo cp biocviewsapi.service /etc/systemd/system/biocviewsapi.service
#
# sudo systemctl daemon-reload
# sudo systemctl start biocviewsapi.service
# sudo systemctl enable biocviewsapi
