# This script is executed by systemd
library(plumber2)

# Define the file containing your endpoints
plumber_file <- "plumber_serve.R"

# Check if the file exists (Optional, but helps with debugging)
if (!file.exists(plumber_file))
    stop("Plumber endpoint file not found: ", plumber_file)

# 1. Load the API router
pa <- api(plumber_file)

# 2. Run the API: This command will block the process, which is exactly
# what systemd expects for a long-running service.
# Use host = "0.0.0.0" if you want it accessible outside the loopback
# for the reverse proxy, but "127.0.0.1" is usually fine if the proxy is on the same machine.
pa |> api_run(host = "127.0.0.1", port = 8000)

## pa |> api_stop()
