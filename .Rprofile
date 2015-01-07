if (file.exists("~/.Rprofile"))
  source("~/.Rprofile")

# Create a new post
create_post <- function(name) {
  date <- Sys.Date()
  file <- file.path(
    "posts",
    paste(date, "-", name, ".Rmd", sep = "")
  )
  cat("---\nlayout: post\ntitle:\ntag:\n---\n\n", file = file)
  file.edit(file)
}
