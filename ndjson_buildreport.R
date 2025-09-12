softreport <- BiocPkgTools:::.get_build_report_tgz_url(
    BiocManager::version(),
    "bioc"
)
report_file <- file.path("~/data", basename(softreport))

download.file(softreport, report_file)

dir.create(
    report_folder <- tempfile()
)

untar(report_file, exdir = report_folder)

softreporttab <- BiocPkgTools:::.read_info_dcfs(report_folder)
softreporttab[["pkgType"]] <- "bioc"

output_file <- "~/data/bioconductor_buildreport.ndjson"
con <- file(output_file, "w")

for (i in seq_len(nrow(softreporttab))) {
    row_list <- as.list(softreporttab[i, ])
    json_line <- jsonlite::toJSON(row_list, auto_unbox = TRUE, null = "null")
    writeLines(json_line, con, sep = "\n")
}

close(con)

readLines(output_file, n = 20)
