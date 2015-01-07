library(knitr)

# Set some knit options
knitr::render_jekyll()

knitr::opts_chunk$set(
  fig.height = 5,
  fig.width = 7.5,
  out.extra = '',
  tidy = FALSE,
  comment = NA,
  results = 'markup',
  cache = TRUE
)

# Ensure knitr documents are knit with this directory
# (not 'post/') as the root directory
knitr::opts_knit$set(root.dir = getwd())

# Ensure the '_posts' directory exists
if (!file.exists("_posts"))
  dir.create("_posts")

# Knit all of the .Rmd documents in post
posts <- list.files("posts", full.names = TRUE)

for (inputPath in posts) {

  # Build the input, output paths
  fileName <- basename(inputPath)
  fileNameSansExtension <-
    tools::file_path_sans_ext(fileName)

  outputPath <- file.path(
    "_posts",
    paste(fileNameSansExtension, ".md", sep = '')
  )

  # Knit away!
  knitr::knit(
    input = inputPath,
    output = outputPath,
    envir = new.env()
  )

}
