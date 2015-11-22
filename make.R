library(knitr)

knitr::opts_chunk$set(
  fig.height = 5,
  fig.width = 7.5,
  out.extra = '',
  tidy = FALSE,
  comment = NA,
  results = 'markup'
)

# Ensure knitr documents are knit with this directory
# (not 'post/') as the root directory
knitr::opts_knit$set(
  root.dir = getwd(),
  base.url = "{{ site.baseurl }}/"
  )

# Insert zero-space UTF-8 characters, to avoid
# a Jekyll bug that strips leading whitespace in output.
knitr::render_markdown(TRUE)

hook.r = function(x, options) {
  stringr::str_c(
    "\n\n{% highlight ",
    tolower(options$engine),
    " %}\n",
    x,
    "\n{% endhighlight %}\n\n"
  )
}

hook.t = function(x, options) {
  stringr::str_c(
    "\n\n{% highlight text %}\n",
    paste("\U200B", x, sep = ""), ## hacky workaround for jekyll bug
    "\n{% endhighlight %}\n\n"
  )
}

knit_hooks$set(source = function(x, options) {
  x = paste(knitr:::hilight_source(x, "markdown", options), collapse = "\n")
  hook.r(x, options)
}, output = hook.t, warning = hook.t, error = hook.t, message = hook.t)

# Ensure the '_posts' directory exists
if (!file.exists("_posts"))
  dir.create("_posts")

if (!file.exists("hash"))
  dir.create("hash")

# Knit all of the .Rmd documents in post
posts <- list.files("posts",
                    pattern = "Rmd$",
                    full.names = TRUE)

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
  if (file.exists(hashPath) && file.exists(outputPath))
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
    envir = globalenv()
  )

}
