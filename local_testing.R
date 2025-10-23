## to test locally
library(plumber2)
pa <- api("plumber_serve.R")
pa |> api_run(host = "127.0.0.1", port = 8000)

pa |> api_stop()
