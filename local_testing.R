## to test locally
library(plumber2)
pa <- api("plumber_serve.R")
pa |> api_run()

pa |> api_stop()
