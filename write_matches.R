library(dplyr)
library(vroom)
library(fs)
library(r2dii.match)

directory <- path_temp()

lbk <- head(r2dii.data::loanbook_demo, 100)
ald <- head(r2dii.data::ald_demo)

write_matches <- function(lbk, ald, path = tempdir()) {
  for (i in 1:nrow(lbk)) {
    out <- match_name(slice(lbk, i), ald)
    if (nrow(out) == 0L) next()
    col_names <- ifelse(i == 1L, TRUE, FALSE)
    vroom_write(out, file.path(path, paste0(i, ".csv")), col_names = col_names)
  }
  
  vroom::vroom(path)
}

path <- tempdir()
benchmark

# fs::dir_ls(directory)
# fs::file_delete(dir_ls(directory))