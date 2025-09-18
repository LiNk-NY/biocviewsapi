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
    ndjson_file <- "bioconductor_packages.ndjson"
    report_file <- "bioconductor_buildreport.ndjson"
    status_file <- "bioconductor_buildstatus.ndjson"

    # Check if the file exists
    if (!file.exists(ndjson_file))
        stop("NDJSON file not found.")

    # Load the NDJSON file directly into a DuckDB table.
    # The 'json' format specifier is what tells DuckDB how to read the file.
    # We'll use the FROM read_json_auto() syntax which is robust.
    dbExecute(
        con,
        paste0(
            "INSTALL json;",
            "CREATE TABLE packages AS SELECT * FROM read_json_auto(?, format = 'newline_delimited');",
            "CREATE TABLE buildreport AS SELECT * FROM read_json_auto(?, format = 'newline_delimited');",
            "CREATE TABLE buildstatus AS SELECT * FROM read_json_auto(?, format = 'newline_delimited')"
        ),
        params = list(ndjson_file)
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
    # Sanitize the query to be used in a LIKE statement
    search_term <- paste0("%", query, "%")

    # Perform a case-insensitive search across multiple columns using SQL.
    # The dbGetQuery function sends the SQL to DuckDB and returns a data frame.
    # Using parameterized queries to prevent SQL injection.
    sql_query <- "
      SELECT * FROM packages
      WHERE
        Package ILIKE ? OR
        Title ILIKE ? OR
        Description ILIKE ?
    "
    results <- dbGetQuery(
        con, sql_query, params = list(search_term, search_term, search_term)
    )

    # Return the results. Plumber will handle JSON serialization automatically.
    results
}

#* Get the version of a specific package.
#* @param name The name of the package.
#* @param res The response object.
#* @get /package/<name>
package_version_handler <- function(name, res) {
    # Find the package with a case-insensitive search
    sql_query <- "SELECT Package, Version FROM packages WHERE Package ILIKE ?"
    result <- dbGetQuery(con, sql_query, params = list(name))

    # If no rows are returned, the package was not found
    if (nrow(result) == 0) {
        res$status <- 404 # Not Found
        return(list(error = paste0("Package '", name, "' not found.")))
    }

    # Return the result (Plumber handles JSON conversion)
    result
}

#* Get the list of packages associated with an email
#* @param email The email address to search for.
#* @get /packages/<email>
email_packages_handler <- function(email) {
    search_term <- paste0("%", email, "%")
    sql_query <- "
      SELECT Package, Version, Author, Maintainer FROM packages
      WHERE
        Author ILIKE ? OR
        Maintainer ILIKE ?
    "
    results <- dbGetQuery(
        con, sql_query, params = list(search_term, search_term)
    )

    # Return the results (Plumber handles JSON conversion)
    results
}
