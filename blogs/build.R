
library(data.table)
library(git2r)


CheckBaseURL <- function() {
  # check for correct baseURL on current branch
  branches <- branches()

  # get head of each known branch
  branch_table <- data.table(
    Branch = names(branches),
    Head =   sapply(branches, function(branch) {
        capture.output(print(branch))
      }))
  
  # get branch name from each head
  branch_name <- function(x) {
    y <- strsplit(x, " ", fixed = TRUE)
    sapply(y, function(z) {
      z[length(z)]
    })
  }
  
  # Get branch of head
  current_branch <- branch_table[regexpr("(HEAD)", Head) != -1, branch_name(Head)]
  current_branch <- current_branch[current_branch != "HEAD"]

  # Get config.toml file
  toml <- readLines("../config.toml")
  
  baseLines <- which(regexpr("baseURL", toml, fixed = TRUE) != -1)
  baseLine <- toml[baseLines[which(substr(toml[baseLines], 1, 1) != "#")]]
  
  googleLines <- which(regexpr("googleAnalytics", toml, fixed = TRUE) != -1)
  googleLine <- toml[googleLines[which(substr(toml[googleLines], 1, 1) != "#")]]
  
  disqusLines <- which(regexpr("disqusShortname", toml, fixed = TRUE) != -1)
  disqusLine <- toml[disqusLines[which(substr(toml[disqusLines], 1, 1) != "#")]]

  if (current_branch == "develop") {
    if (regexpr("https://mystifying-dubinsky-8d3673.netlify.com/", baseLine, fixed = TRUE) == -1) {
      stop("Wrong baseURL for this branch!")
    }
      
    if (regexpr("no key", googleLine, fixed = TRUE) == -1) {
      stop("Wrong Google Analytics Key for this branch!")
    }
    
    if (regexpr("markklik", disqusLine, fixed = TRUE) == -1) {
      stop("Wrong Disqus for this branch!")
    }
  }
  
  if (current_branch == "preview") {
    if (regexpr("https://compassionate-davinci-793.netlify.com", baseLine, fixed = TRUE) == -1) {
      stop("Wrong baseURL for this branch!")
    }
      
    if (regexpr("UA-111250101-2", googleLine, fixed = TRUE) == -1) {
      stop("Wrong Google Analytics Key for this branch!")
    }
    
    if (regexpr("markklik", disqusLine, fixed = TRUE) == -1) {
      stop("Wrong Disqus for this branch!")
    }
  }
  

  if (current_branch == "master") {
    if (regexpr("http://blog.fstpackage.org", baseLine, fixed = TRUE) == -1) {
      stop("Wrong baseURL for this branch!")
    }

    if (regexpr("UA-111250101-1", googleLine, fixed = TRUE) == -1) {
      stop("Wrong Google Analytics Key for this branch!")
    }
    
    if (regexpr("fst-blog", disqusLine, fixed = TRUE) == -1) {
      stop("Wrong Disqus for this branch!")
    }
  }
}

# Tst correct baseURL set in config.toml
CheckBaseURL()


# currently active blog to compile
# blog_name <- "fst_0.8.0"
# blog_name <- "fst_compression"
blog_name <- "fst_hashing"


blog <- paste0(blog_name, ".Rmd")
post_dir <- paste0("../content/post/", blog_name)
post_file <- paste0("../content/post/",  blog_name, "/", blog_name, ".md")

# create an image subdirectory for the post
if (!file.exists("../static/img")) {
  dir.create("../static/img/")
}

img_dir <- paste0("../static/img/", blog_name)
if (!file.exists(img_dir)) {
  dir.create(img_dir)
}

# create blog dir if non-existing
if (!file.exists(post_dir)) {
  dir.create(post_dir)
} else
{
  file.remove(post_file)
}

# compile from blog directory
setwd(blog_name)


# knit blog
knitr::knit(blog, paste0("../", post_file))


# copy generated images and media
file.copy("img", paste0("../", img_dir), overwrite = TRUE, recursive = TRUE)
file.copy("media", paste0("../", img_dir), overwrite = TRUE, recursive = TRUE)

setwd("..")


# replace all image references with correct reference
lines <- readLines(post_file)
lines <- gsub("img/fig-", paste0("/img/", blog_name, "/img/fig-"), lines, fixed = TRUE)
writeLines(lines, post_file)


# blogdown::serve_site()

# blogdown::hugo_version()
