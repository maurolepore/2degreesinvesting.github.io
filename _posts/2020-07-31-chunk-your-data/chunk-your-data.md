Chunk your data
================
true
2020-07-31

Users of the
[r2dii.match](https://2degreesinvesting.github.io/r2dii.match/) package
reported that their R session crashed when they fed `match_name()` with
big data. A [recent
post](https://2degreesinvesting.github.io/posts/2020-07-18-improving-r2dii-match/)
acknowledged the issue and promised examples on how to handle big data.
This article shows one approach: feed
[`match_name()`](https://2degreesinvesting.github.io/r2dii.match/reference/match_name.html)
with a sequence of small chunks of the `loanbook` dataset.

## Setup

I’ll use r2dii.match plus a few optional but convenient packages,
including [r2dii.data](https://2degreesinvesting.github.io/r2dii.data/)
for example datasets.

``` r
# Packages
library(dplyr, warn.conflicts = FALSE)
library(fs)
library(vroom)
library(r2dii.data)
library(r2dii.match)

# Example datasets from the r2dii.data package
loanbook <- loanbook_demo
ald <- ald_demo
```

You need to “split” the `loanbook` dataset in chunks small enough so
that any call to `match_name(this_chunk, ald)` fits in memory. More
chunks take longer to run but use less memory; you’ll need to experiment
to find the number of chunks that best works for you.

Let’s add the new column `chunk` to assign each row to one of `n`
chunks.

``` r
n <- 3
chunked <- loanbook %>% mutate(chunk = as.integer(cut(row_number(), breaks = n)))

# How many rows and columns in the entire loanbook?
dim(loanbook)
#> [1] 320  19

# How many [rows x columns] in each chunk?
chunked %>% nest_by(chunk)
#> # A tibble: 3 x 2
#> # Rowwise:  chunk
#>   chunk                data
#>   <int> <list<tbl_df[,19]>>
#> 1     1          [107 × 19]
#> 2     2          [106 × 19]
#> 3     3          [107 × 19]
```

For each chunk we need to repeat this process:

1.  Feed `match_name()` with one `loanbook` chunk.
2.  Match this chunk against the entire `ald` dataset.
3.  Save the result to a .csv file.

<!-- end list -->

``` r
# Store each result in this folder
out <- "output"
if (!dir_exists(out)) dir_create(out)

for (i in unique(chunked$chunk)) {
  this_chunk <- filter(chunked, chunk == i)
  this_result <- match_name(this_chunk, ald)
  
  # If this chunk matched nothing, skip saving and move to the next chunk
  matched_nothing <- nrow(this_result) == 0L
  if (matched_nothing) next()
  
  this_result %>% vroom_write(path(out, paste0(i, ".csv")))
}
```

The result is one .csv file per chunk.

``` r
dir_ls(out)
#> output/1.csv output/2.csv output/3.csv
```

You can read and combine all files in one step with `vroom()`.

``` r
dir_ls(out) %>% vroom()
#> Rows: 502
#> Columns: 29
#> Delimiter: "\t"
#> chr [20]: id_loan, id_direct_loantaker, name_direct_loantaker, id_intermediate_parent_1, n...
#> dbl [ 6]: rowid, loan_size_outstanding, loan_size_credit_limit, sector_classification_dire...
#> lgl [ 3]: name_project, lei_direct_loantaker, isin_direct_loantaker
#> 
#> Use `spec()` to retrieve the guessed column specification
#> Pass a specification to the `col_types` argument to quiet this message
#> # A tibble: 502 x 29
#>    rowid id_loan id_direct_loant… name_direct_loa… id_intermediate…
#>    <dbl> <chr>   <chr>            <chr>            <chr>           
#>  1     1 L1      C294             Yuamen Xinneng … <NA>            
#>  2     3 L3      C292             Yuama Ethanol L… IP5             
#>  3     3 L3      C292             Yuama Ethanol L… IP5             
#>  4     5 L5      C305             Yukon Energy Co… <NA>            
#>  5     5 L5      C305             Yukon Energy Co… <NA>            
#>  6     6 L6      C304             Yukon Developme… <NA>            
#>  7     6 L6      C304             Yukon Developme… <NA>            
#>  8     8 L8      C303             Yueyang City Co… <NA>            
#>  9     9 L9      C301             Yuedxiu Corp One IP10            
#> 10    10 L10     C302             Yuexi County AA… <NA>            
#> # … with 492 more rows, and 24 more variables:
#> #   name_intermediate_parent_1 <chr>, id_ultimate_parent <chr>,
#> #   name_ultimate_parent <chr>, loan_size_outstanding <dbl>,
#> #   loan_size_outstanding_currency <chr>, loan_size_credit_limit <dbl>,
#> #   loan_size_credit_limit_currency <chr>, sector_classification_system <chr>,
#> #   sector_classification_input_type <chr>,
#> #   sector_classification_direct_loantaker <dbl>, fi_type <chr>,
#> #   flag_project_finance_loan <chr>, name_project <lgl>,
#> #   lei_direct_loantaker <lgl>, isin_direct_loantaker <lgl>, chunk <dbl>,
#> #   id_2dii <chr>, level <chr>, sector <chr>, sector_ald <chr>, name <chr>,
#> #   name_ald <chr>, score <dbl>, source <chr>
```

## Anecdote

I tested `match_name()` with datasets which size (on disk as a .csv
file) was 20MB for the `loanbook` dataset and 100MB for the `ald`
dataset. Feeding `match_name()` with the entire `loanbook` crashed my R
session. But feeding it with a sequence of 30 chunks run in about 25’ –
successfully; the result combined had over 10 million rows:

    sector                       data
    ---------------------------------
    1 automotive     [2,644,628 × 15]
    2 aviation         [377,200 × 15]
    3 cement           [942,526 × 15]
    4 oil and gas    [1,551,805 × 15]
    5 power          [7,353,772 × 15]
    6 shipping       [4,194,067 × 15]
    7 steel                 [15 × 15]
