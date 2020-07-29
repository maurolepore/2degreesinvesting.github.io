library(dplyr)
library(vroom)
library(fs)
library(r2dii.match)

directory <- path("output")

# lbk <- head(r2dii.data::loanbook_demo, 100)
# ald <- head(r2dii.data::ald_demo)
lbk <- vroom("~/Downloads/tmp/lbk-20mb.csv")
ald <- vroom("~/Downloads/tmp/ald-100mb.csv")

for (i in 1:nrow(lbk)) {
  out <- match_name(slice(lbk, i), ald)
  if (nrow(out) == 0L) next()
  vroom_write(out, file.path(directory, paste0(i, ".csv")))
}

# fs::dir_ls(directory)
# fs::file_delete(dir_ls(directory))
