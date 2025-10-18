library(plumber)
library(duckdb)
library(jsonlite)
library(dplyr)

# --- DuckDB Setup ---

# Create an in-memory DuckDB database connection
# This will be shared across all API endpoints
con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:", read_only = FALSE)

load_data <- function() {
    # Define the path to your NDJSON file
    packages_file <- "bioconductor_packages.ndjson"
    report_file <- "bioconductor_buildreport.ndjson"
    status_file <- "bioconductor_buildstatus.ndjson"

    # Check if the file exists
    if (!file.exists(packages_file))
        stop("Packages NDJSON file not found.")

    dbExecute(con, "INSTALL json")
    dbExecute(con, "LOAD json")

    dbExecute(
        con,
        "CREATE OR REPLACE TABLE packages AS SELECT * FROM read_json_auto(?, format = 'newline_delimited')",
        params = list(packages_file)
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

#* @apiTitle Bioconductor Package Search API
#* @apiDescription An API for searching package metadata using DuckDB.

#* Search for packages by a query string in multiple fields.
#* @param query The search term.
#* @get /search
search_handler <- function(query) {
    packages_tbl <- tbl(con, "packages")

    results <- packages_tbl |>
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
#* @get /package/<name>
package_version_handler <- function(name, res) {
    packages_tbl <- tbl(con, "packages")

    result <- packages_tbl |>
        filter(Package == name) |>
        select(Package, Version) |>
        collect()

    # If no rows are returned, the package was not found
    if (nrow(result) == 0) {
        res$status <- 404 # Not Found
        return(list(error = paste0("Package '", name, "' not found.")))
    }

    result
}

#* Get the list of packages associated with an email
#* @param email The email address to search for.
#* @get /packages/<email>
email_packages_handler <- function(email) {
    search_term <- paste0("%", email, "%")
    pkgtbl <- email_packages_handler(email)
    pkgs <- pkgtbl[["Package"]]

    buildstatus_tbl <- tbl(con, "buildstatus")
    packages_tbl <- tbl(con, "packages")

    maintainer_pkgs <- packages_tbl |>
        filter(grepl(email, Maintainer, ignore.case = TRUE))

    results <- buildstatus_tbl |>
        semi_join(maintainer_pkgs, by = c("pkg" = "Package")) |>
        collect()

    results
}
