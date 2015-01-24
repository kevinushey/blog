if (file.exists("~/.Rprofile"))
  source("~/.Rprofile")

# Create a new post
create_post <- new_post <- post <- function(title, tags = "r") {

  date <- Sys.Date()
  name <- tolower(gsub("[\\s_]", "-", title, perl = TRUE))

  file <- file.path(
    "posts",
    paste(date, "-", name, ".Rmd", sep = "")
  )

  yaml <- list(
    layout = "post",
    title = title,
    tags = paste(tags, collapse = ", "),
    comments = "true",
    NULL
  )

  padding <- max(nchar(names(yaml)))

  yamlText <- paste(collapse = "\n", c(
    "---",
    lapply(seq_along(yaml), function(i) {
      whitespace <- paste(collapse = "", rep(" ", padding - nchar(names(yaml)[i]) + 1))
      paste(names(yaml)[i], whitespace, ": ", yaml[[i]], sep = "")
    }),
    "---"
  ))

  cat(yamlText, file = file)
  file.edit(file)
}
