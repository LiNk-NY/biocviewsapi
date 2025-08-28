FROM rstudio/plumber:latest

ENV CRAN='https://p3m.dev/cran/__linux__/noble/latest'

RUN R -e 'install.packages(c("duckdb", "jsonlite", "dplyr"))'

WORKDIR /app

COPY plumber2_ndjson.R .
COPY bioconductor_packages.ndjson .

EXPOSE 8000

CMD ["plumber2_ndjson.R"]

