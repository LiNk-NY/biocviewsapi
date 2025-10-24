library(plumber2)
library(duckdb)
library(jsonlite)
library(dplyr)
library(reqres)
library(utils)

# --- DuckDB Setup ---

# Create an in-memory DuckDB database connection
# This will be shared across all API endpoints
con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:", read_only = FALSE)

load_data <- function() {
    # Define the path to your NDJSON file
    ndjson_file <- "bioconductor_packages.ndjson"
    report_file <- "bioconductor_buildreport.ndjson"
    status_file <- "bioconductor_buildstatus.ndjson"

    # Check if the file exists
    if (!file.exists(ndjson_file))
        stop("NDJSON file not found.")

    dbExecute(con, "INSTALL json")
    dbExecute(con, "LOAD json")

    dbExecute(
        con,
        "CREATE OR REPLACE TABLE packages AS SELECT * FROM read_json_auto(?, format = 'newline_delimited')",
        params = list(ndjson_file)
    )

    dbExecute(
        con,
        "CREATE OR REPLACE TABLE buildreport AS SELECT * FROM read_json_auto(?, format = 'newline_delimited')",
        params = list(report_file)
    )

    dbExecute(
        con,
        "CREATE OR REPLACE TABLE buildstatus AS SELECT * FROM read_json_auto(?, format = 'newline_delimited')",
        params = list(status_file)
    )
}

# Run the data loading function at startup
load_data()

# --- Plumber API Endpoints ---

#* Bioconductor Package Search API
#*
#* Search for packages by a query string in multiple fields.
#*
#* @get /search
#*
#* @query term:string* Filter Package, Title and Description fields to those
#*   matching the term.
#*
#* @serializer json
#*
#* @response 200:string A JSON array of package records matching the search
#*   term.
search_handler <- function(query) {
    views_tbl <- tbl(con, "views")

    results <- views_tbl |>
        filter(
            grepl(query$term, Package, ignore.case = TRUE) |
            grepl(query$term, Title, ignore.case = TRUE) |
            grepl(query$term, Description, ignore.case = TRUE)
        ) |>
        collect()

    results
}

#* Get the version of a package
#*
#* @get /package/version/<name>
#*
#* @param name:string* The name of the package
#*
#* @serializer json
#*
#* @response 200:string A JSON object containing the package version
#*
#* @response 404:string If the package is not found.
#*
package_version_handler <- function(name) {
    views_tbl <- tbl(con, "views")

    result <- views_tbl |>
        filter(Package == name) |>
        select(Version) |>
        collect()

    # If no rows are returned, the package was not found
    if (!nrow(result)) {
        reqres::abort_not_found(
            detail = paste0("Package '", name, "' not found.")
        )
    }

    result
}

#* Get the list of packages associated with an email
#*
#* @get /views/<email>
#*
#* @param email* The email address to search for.
#*
#* @serializer json
#*
#* @response 200:string A JSON array of package records associated with the
#*   email.
email_views_handler <- function(email) {
    email <- utils::URLdecode(email)

    views_tbl <- tbl(con, "views")

    results <- views_tbl |>
        filter(
            grepl(email, Maintainer, ignore.case = TRUE)
        ) |>
        select(Package, Version, Author, Maintainer) |>
        collect()

    if (!nrow(results))
        reqres::abort_not_found(
            detail = paste0("No packages found for email '", email, "'.")
        )

    results
}

#* Get build report for a specific package.
#*
#* @get /checkResults/package/<name>
#*
#* @param name The name of the package.
#*
#* @serializer json
#*
#* @response 200:string A JSON object containing the build report for the
#*  package.
#*
#* @response 404:string If the package build report is not found.
#*
checkResults_package_handler <- function(name, res) {
    buildreport_tbl <- tbl(con, "buildreport")

    result <- buildreport_tbl |>
        filter(pkg == name) |>
        collect()

    if (!nrow(result)) {
        reqres::abort_not_found(
            detail = paste0("Build report for package '", name, "' not found.")
        )
    }
    result
}

#* Get build status for a maintainer email
#*
#* @get /checkResults/maintainer/<email>
#*
#* @param email The email address to search for.
#*
#* @serializer json
#*
#* @response 200:string A JSON array of build status records for packages
#*   associated with the email
checkResults_maintainer_handler <- function(email) {
    email <- utils::URLdecode(email)

    buildstatus_tbl <- tbl(con, "buildstatus")
    views_tbl <- tbl(con, "views")

    maintainer_pkgs <- views_tbl |>
        filter(grepl(email, Maintainer, ignore.case = TRUE))

    results <- buildstatus_tbl |>
        semi_join(maintainer_pkgs, by = c("pkg" = "Package")) |>
        collect()

    results
}
