# biocviewsapi

This project aims to provide a simple and efficient API for accessing
data from Bioconductor Build System (BBS) including the VIEWS file, the BBS
build report, and BBS build status files. The API is designed to facilitate the
retrieval and parsing of these data sources for use in various applications.

## Data Sources

Note that the URLs provided below are specific to Bioconductor version 3.21.

The `VIEWS` file can be seen at
<https://bioconductor.org/packages/3.21/bioc/VIEWS>.

The BBS build report is available at
<https://bioconductor.org/checkResults/3.21/bioc-LATEST/report.tgz>

The BBS build status database file can be found at
<https://bioconductor.org/checkResults/3.21/bioc-LATEST/BUILD_STATUS_DB.txt>

## Installation

For testing, first install the required packages:

```r
BiocManager::install(
    c("plumber2", "duckdb", "jsonlite", "dplyr", "reqres")
)
```

## Usage

`biocviewsapi` is a service that is meant to be run on a server.

Test the service interactively by running the `run_plumber.R` script
within an `RStudio` session or from an R terminal:

```r
library(plumber2)

pa <- api("biocpkgtools_serve.R")
pa |> api_run(host = "127.0.0.1", port = 8000)
```

This will start the API server at <http://127.0.0.1:8000/__docs__/> where you
can view the API documentation and review the endpoints.

Once the service is running, you can access the API endpoints using a web
browser or tools like `curl`.

For example, to search through Bioconductor package names, titles, and
descriptions, you can visit <http://127.0.0.1:8000/search?term=metabolomics>
within your web browser. Note that the `term` parameter is used along with the
example term "metabolomics".

### API Endpoints

The API provides the following endpoints:

- `/search`: Search Bioconductor package names, titles, and descriptions.
  - **Parameters**:
    - `term`: The search term to look for in package names, titles, and
      descriptions.
- `/package/version/<name>`: Get the version of a package given the package name.
    - **Parameters**:
        - `name`: The name of the package, e.g., "SummarizedExperiment".
- `/views/<email>`: Get a list of packages associated with a maintainer's email.
    - **Parameters**:
        - `email`: The email address of the maintainer, e.g., "seandavi@gmail.com".
- `/checkResults/package/<name>`: Get the build report for a specific package.
    - **Parameters**:
        - `name`: The name of the package, e.g., "SummarizedExperiment".
- `/checkResults/maintainer/<email>`: Get the build status for packages
  associated with a maintainer's email.
    - **Parameters**:
        - `email`: The email address of the maintainer, e.g.,
          "seandavi@gmail.com".

### Requests via `httr2`

```r
library(httr2)
paste0("http://127.0.0.1:8000/", "views/", main) |>
    request() |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)
```

## biocapi

The `biocapi` package provides an R client for interacting with the
`biocviewsapi` service. It simplifies the process of making requests to the
API and handling the responses.

See the `biocapi` package documentation for more details on how to use it.

<https://github.com/LiNk-NY/biocapi>

## License

This project is licensed under the MIT License. See the `LICENSE` file for more
details.

