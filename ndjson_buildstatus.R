softstatus <- BiocPkgTools:::get_build_status_db_url(
    BiocManager::version(),
    pkgType = "bioc"
)
download.file(
    softstatus,
    "~/data/BUILD_STATUS_DB.txt"
)

dat <- readLines("~/data/BUILD_STATUS_DB.txt") |>
    strsplit(x = _, "#|:\\s") |>
    do.call(rbind.data.frame, args = _)
names(dat) <- c("pkg", "node", "stage", "result")

output_file <- "bioconductor_buildstatus.ndjson"
con <- file(output_file, "w")


for (i in seq_len(nrow(dat))) {
    row_list <- as.list(dat[i, ])
    json_line <- jsonlite::toJSON(row_list, auto_unbox = TRUE, null = "null")
    writeLines(json_line, con, sep = "\n")
}

close(con)

readLines(output_file, n = 20)
