library(plumber)
library(duckdb)
library(jsonlite)
library(dplyr)

# --- DuckDB Setup ---

# Create an in-memory DuckDB database connection
# This will be shared across all API endpoints
con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:", read_only = FALSE)

load_data <- function() {
    ## Generate buildreport data.frame from live DB file
    buildreport <- BiocPkgTools::biocBuildReportDB(
        version = BiocManager::version(),
        pkgType = "software"
    )
    dbWriteTable(con, "buildreport", buildreport, overwrite = TRUE)

    ## Generate buildstatus data.frame from live DB file
    buildstatus <- BiocPkgTools::biocBuildStatusDB(
        version = BiocManager::version(),
        pkgType = "software"
    )
    dbWriteTable(con, "buildstatus", buildstatus, overwrite = TRUE)

    ## Generate views data.frame from live VIEWS file
    views_url <- "https://bioconductor.org/packages/devel/bioc/VIEWS"
    views_file <- file.path(tempdir(), "VIEWS")
    download.file(url = views_url, destfile = views_file)

    views <- read.dcf(views_file) |>
        as.data.frame(stringsAsFactors = FALSE)

    ## commaCols <- c(
    ##     'Depends', 'Suggests', 'dependsOnMe', 'Imports', 'importsMe',
    ##     'Enhances', 'vignettes', 'vignetteTitles', 'suggestsMe', 'Maintainer',
    ##     'biocViews', 'Archs', 'linksToMe', 'LinkingTo', 'Rfiles'
    ## )
    ## isCommaCol <- colnames(views) %in% commaCols
    ## views[isCommaCol] <- lapply(
    ##     views[isCommaCol],
    ##     function(x) stringr::str_split(x, '\\s?,\\s?')
    ## )
    views[["Author"]] <-
        views[["Author"]] |>
        gsub("\n", " ", x = _) |>
        gsub("\\[.*?\\]", "", x = _) |>
        gsub("<.*?>", "", x = _) |>
        gsub("\\(.*?\\)", "", x = _) |>
        gsub("\\s+", " ", x = _) |>
        strsplit(split = "\\s*,\\s*") |>
        lapply(X = _, FUN = function(authors) {
            gsub("\\w* contributions ?\\w*", ", ", authors) |>
                gsub("\\sand\\s", ", ", x = _) |>
                gsub(",\\s+,", ",", x = _) |>
                gsub("\\.+$", "", x = _) |>
                trimws(x = _) |>
                paste(collapse = ", ")
        }) |>
        unlist(recursive = FALSE)

    dbWriteTable(con, "views", views, overwrite = TRUE)
}

# Run the data loading function at startup
load_data()

# --- Plumber API Endpoints ---

#* @apiTitle Bioconductor Package Search API
#* @apiDescription An API for searching package metadata using DuckDB.

#* Search for packages by a query string in multiple fields.
#* @param query The search term.
#* @get /search
search_handler <- function(query) {
    views_tbl <- tbl(con, "views")

    results <- views_tbl |>
        filter(
            grepl(query, Package, ignore.case = TRUE) |
            grepl(query, Title, ignore.case = TRUE) |
            grepl(query, Description, ignore.case = TRUE)
        ) |>
        collect()

    results
}

#* Get the version of a specific package.
#* @param name The name of the package.
#* @param res The response object.
#* @get /package/version/<name>
package_version_handler <- function(name, res) {
    views_tbl <- tbl(con, "views")

    result <- views_tbl |>
        filter(Package == name) |>
        select(Version) |>
        collect()

    # If no rows are returned, the package was not found
    if (!nrow(result)) {
        res$status <- 404 # Not Found
        return(list(error = paste0("Package '", name, "' not found.")))
    }

    result
}

#* Get the list of packages associated with an email
#* @param email The email address to search for.
#* @get /views/<email>
email_views_handler <- function(email) {
    views_tbl <- tbl(con, "views")

    results <- views_tbl |>
        filter(
            grepl(email, Author, ignore.case = TRUE) |
            grepl(email, Maintainer, ignore.case = TRUE)
        ) |>
        select(Package, Version, Author, Maintainer) |>
        collect()

    results
}

#* Get build report for a specific package.
#* @param name The name of the package.
#* @get /checkResults/package/<name>
checkResults_package_handler <- function(name, res) {
    buildreport_tbl <- tbl(con, "buildreport")

    result <- buildreport_tbl |>
        filter(pkg == name) |>
        collect()

    if (!nrow(result)) {
        res$status <- 404 # Not Found
        return(
            list(
                error =
                    paste0("Build report for package '", name, "' not found.")
            )
        )
    }
    result
}

#* Get build status for a maintainer email
#*
#* @param email The email address to search for.
#* @get /checkResults/maintainer/<email>
checkResults_maintainer_handler <- function(email) {

    buildstatus_tbl <- tbl(con, "buildstatus")
    views_tbl <- tbl(con, "views")

    maintainer_pkgs <- views_tbl |>
        filter(grepl(email, Maintainer, ignore.case = TRUE))

    results <- buildstatus_tbl |>
        semi_join(maintainer_pkgs, by = c("pkg" = "Package")) |>
        collect()

    results
}
