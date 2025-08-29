#!/bin/bash 

# docker pull rstudio/plumber
docker build -t my-plumber-api .

docker run -it -p 8080:8000 my-plumber-api:latest /app/plumber2_ndjson.R
