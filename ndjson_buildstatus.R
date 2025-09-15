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

output_file <- "~/data/bioconductor_buildstatus.ndjson"
con <- file(output_file, "w")

splitdat <- split(dat[, -1], dat$pkg)

for (pkgname in names(splitdat)) {
    pkg <- splitdat[[pkgname]]
    pkglist <- list(
        split(pkg[, names(pkg) != "node"], pkg$node)
    )
    names(pkglist) <- pkgname
    jsonlite::toJSON(
        pkglist, auto_unbox = TRUE, null = "null", pretty = TRUE
    ) |>
    writeLines(text = _, con = con, sep = "\n")
}

close(con)

readLines(output_file, n = 20)
