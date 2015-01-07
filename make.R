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

  # Check to see if the .Rmd file has actually changed.
  # If not, then don't knit it.
  hashPath <- file.path("hash", fileNameSansExtension)
  if (file.exists(hashPath))
  {
    md5sum <- unname(tools::md5sum(inputPath))
    hash <- scan(what = character(),
                 file = hashPath,
                 quiet = TRUE)

    if (identical(hash, c(md5sum)))
      next
  }

  # Generate a hash for the file and knit
  md5sum <- tools::md5sum(inputPath)
  cat(md5sum, file = hashPath, sep = "\n")

  knitr::knit(
    input = inputPath,
    output = outputPath,
    envir = new.env()
  )

}
