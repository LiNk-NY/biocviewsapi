download.file(
    "https://bioconductor.org/packages/devel/bioc/VIEWS",
    "~/data/VIEWS"
)

views <- read.dcf("~/data/VIEWS")

viewsdf <- as.data.frame(views, stringsAsFactors = FALSE)

output_file <- "bioconductor_packages.ndjson"
con <- file(output_file, "w")

for (i in seq_len(nrow(viewsdf))) {
    row_list <- as.list(viewsdf[i, ])
    json_line <- jsonlite::toJSON(row_list, auto_unbox = TRUE, null = "null")
    writeLines(json_line, con, sep = "\n")
}

close(con)

readLines(output_file, n = 1)
