Working with big data
================
true
07-20-2020

## Setup

``` r
# Packages
library(tidyverse)
#> ── Attaching packages ────────────────── tidyverse 1.3.0 ──
#> ✓ ggplot2 3.3.2     ✓ purrr   0.3.4
#> ✓ tibble  3.0.3     ✓ dplyr   1.0.0
#> ✓ tidyr   1.1.0     ✓ stringr 1.4.0
#> ✓ readr   1.3.1     ✓ forcats 0.5.0
#> ── Conflicts ───────────────────── tidyverse_conflicts() ──
#> x dplyr::filter() masks stats::filter()
#> x dplyr::lag()    masks stats::lag()
library(fs)
#> Warning: package 'fs' was built under R version 4.0.2
library(vroom)
library(bench)
library(ggplot2)
library(r2dii.data)
library(r2dii.match)
packageVersion("r2dii.match")
#> [1] '0.0.3.9001'

# Example datasets
lbk_full <- loanbook_demo
ald_full <- ald_demo
```

## How do you eat an elephant?

One way to save time and memory is to use less data. Even if you
downsize your data, you may achieve the exact same result, or achieve a
slightly different result that is equally informative.

### Use just the columns you need

Your loanbook dataset may be unnecessarily big; it may have columns that
`match_name()` doesn’t use but make it less efficient. If you feed
`match_name()` with only the crucial columns it needs, you may save time
and memory.

``` r
dim(lbk_full)
#> [1] 320  19

lbk_smaller <- lbk_full %>% select(crucial_lbk())
dim(lbk_smaller)
#> [1] 320   6
```

Compare:

``` r
benchmark <- bench::mark(
  check = FALSE,
  # iterations = 30,
  bigger = match_name(lbk_full, ald_demo),
  smaller  = match_name(lbk_smaller, ald_demo)
)

benchmark %>% autoplot()
```

![](working-with-big-data_files/figure-gfm/unnamed-chunk-3-1.png)<!-- -->

The difference here is small, but can increase with the size of the
data.

## Chunk your data

Before you saw that one way to save time and memory is to use fewer
columns of the loanbook dataset. And you can work yet more efficiently
if you use fewer rows of the ald dataset. One way is to focus on a
single sector.

``` r
ald_full %>% dim()
#> [1] 17368    13
ald_full %>% filter(sector == "power") %>% dim()
#> [1] 8187   13
```

Compared to using the full datasets, this should use less time and
memory.

``` r
benchmark <- bench::mark(
  check = FALSE,
  # iterations = 30,
  bigger = match_name(lbk_full, ald_full),
  smaller = match_name(lbk_smaller, filter(ald_full, sector == "power"))
)

benchmark %>% autoplot()
```

![](working-with-big-data_files/figure-gfm/unnamed-chunk-5-1.png)<!-- -->

To study multiple sectors you can process each one at a time. Each
result may be large, and storing it in memory may cause your computer to
crash. Instead, you can save the output of each sector to a file.

``` r
# Create a directory to store the output
if (!dir_exists("sectors")) dir_create("sectors")

power <- match_name(lbk_smaller, filter(ald_full, sector == "power"))
power %>% vroom_write(path("sectors", "power.csv"))

aviation <- match_name(lbk_smaller, filter(ald_full, sector == "aviation"))
aviation %>% vroom_write(path("sectors", "aviation.csv"))

dir_ls("sectors")
#> sectors/aviation.csv sectors/power.csv
```

When you are ready, combine all results and continue the analysis.

``` r
sectors <- dir_ls("sectors") %>% vroom()
#> Rows: 184
#> Columns: 15
#> Delimiter: "\t"
#> chr [12]: id_ultimate_parent, name_ultimate_parent, id_direct_loantaker, name_direct_loant...
#> dbl [ 3]: rowid, sector_classification_direct_loantaker, score
#> 
#> Use `spec()` to retrieve the guessed column specification
#> Pass a specification to the `col_types` argument to quiet this message
sectors
#> # A tibble: 184 x 15
#>    rowid id_ultimate_par… name_ultimate_p… id_direct_loant… name_direct_loa…
#>    <dbl> <chr>            <chr>            <chr>            <chr>           
#>  1   316 UP7              Airasia X Bhd    C3               Airasia X Bhd   
#>  2   316 UP7              Airasia X Bhd    C3               Airasia X Bhd   
#>  3   317 UP8              Airbaltic        C4               Airbaltic       
#>  4   317 UP8              Airbaltic        C4               Airbaltic       
#>  5   318 UP9              Airblue          C5               Airblue         
#>  6   318 UP9              Airblue          C5               Airblue         
#>  7   319 UP10             Airborne Of Swe… C6               Airborne Of Swe…
#>  8   319 UP10             Airborne Of Swe… C6               Airborne Of Swe…
#>  9   320 UP11             Airbus Transpor… C7               Airbus Transpor…
#> 10   320 UP11             Airbus Transpor… C7               Airbus Transpor…
#> # … with 174 more rows, and 10 more variables:
#> #   sector_classification_system <chr>,
#> #   sector_classification_direct_loantaker <dbl>, id_2dii <chr>, level <chr>,
#> #   sector <chr>, sector_ald <chr>, name <chr>, name_ald <chr>, score <dbl>,
#> #   source <chr>
```

Let’s see how many matches we got per sector:

``` r
sectors %>% count(sector)
#> # A tibble: 2 x 2
#>   sector       n
#>   <chr>    <int>
#> 1 aviation    10
#> 2 power      174
```

Cleanup

``` r
dir_ls("sectors") %>% file_delete()
```

## Slice loanbook by row

What if your dataset is so large than even one sector is too big? Or
what if you want to try matches across sectors?

You can slice each row of the `loanboook` dataset and match it against
the entire `ald` dataset; then if that row matched nothing, discard it,
else save the result to a file. Before you try this approach, beware it
can be painfully slow; but it should work even if you have little
memory.

``` r
if (!dir_exists("rowwise")) dir_create("rowwise")

loanbook <- head(lbk_smaller, 20)
ald <- ald_full
for (i in 1:nrow(loanbook)) {
  out <- match_name(slice(loanbook, i), ald)
  if (nrow(out) == 0L) next()
  out %>% vroom_write(path("rowwise", paste0(i, ".csv")))
}
```

The output directory now contains one file per matching row.

``` r
dir_ls("rowwise") %>% length()
#> [1] 16
```

But we can treat it as a single file because `vroom()` can read them all
at once and produce a single data frame.

``` r
rowwise <- dir_ls("rowwise") %>% vroom()
#> Rows: 22
#> Columns: 15
#> Delimiter: "\t"
#> chr [12]: id_ultimate_parent, name_ultimate_parent, id_direct_loantaker, name_direct_loant...
#> dbl [ 3]: rowid, sector_classification_direct_loantaker, score
#> 
#> Use `spec()` to retrieve the guessed column specification
#> Pass a specification to the `col_types` argument to quiet this message
rowwise
#> # A tibble: 22 x 15
#>    rowid id_ultimate_par… name_ultimate_p… id_direct_loant… name_direct_loa…
#>    <dbl> <chr>            <chr>            <chr>            <chr>           
#>  1     1 UP15             Alpine Knits In… C294             Yuamen Xinneng …
#>  2     1 UP32             Bhagwan Energy … C302             Yuexi County AA…
#>  3     1 UP81             Dynegy Midwest … C309             Yuxi ounty Liua…
#>  4     1 UP269            Summit Meghnagh… C298             Yuba vdf County…
#>  5     1 UP69             Consorcio Integ… C297             Yuba City Cogen…
#>  6     1 UP69             Consorcio Integ… C297             Yuba City Cogen…
#>  7     1 UP3              Affinity Renewa… C296             Yuasfnjiang Ele…
#>  8     1 UP196            Noshiro Forest … C295             Yuanbsaoshan Po…
#>  9     1 UP196            Noshiro Forest … C295             Yuanbsaoshan Po…
#> 10     1 UP196            Noshiro Forest … C295             Yuanbsaoshan Po…
#> # … with 12 more rows, and 10 more variables:
#> #   sector_classification_system <chr>,
#> #   sector_classification_direct_loantaker <dbl>, id_2dii <chr>, level <chr>,
#> #   sector <chr>, sector_ald <chr>, name <chr>, name_ald <chr>, score <dbl>,
#> #   source <chr>

rowwise %>% count(sector)
#> # A tibble: 1 x 2
#>   sector     n
#>   <chr>  <int>
#> 1 power     22
```

Cleanup

``` r
dir_ls("rowwise") %>% file_delete()
```

## Arbitrary “chunks” of loanbook data

Feeding `match_name()` with individual can be too slow. You can feed
`match_name()` with “chunks” of your `loanbook` dataset that are bigger
than a single row, yet small enough you can process each chunk with
whatever memory you have.

``` r
chunkid <- function(n) as.integer(cut(row_number(), breaks = n))

chunked <- lbk_smaller %>% mutate(chunkid = chunkid(100))

chunked %>% nest_by(chunkid)
#> # A tibble: 100 x 2
#> # Rowwise:  chunkid
#>    chunkid               data
#>      <int> <list<tbl_df[,6]>>
#>  1       1            [4 × 6]
#>  2       2            [3 × 6]
#>  3       3            [3 × 6]
#>  4       4            [3 × 6]
#>  5       5            [3 × 6]
#>  6       6            [4 × 6]
#>  7       7            [3 × 6]
#>  8       8            [3 × 6]
#>  9       9            [3 × 6]
#> 10      10            [3 × 6]
#> # … with 90 more rows
```

Now we can match the entire `ald` dataset not with an individual row but
with an individual chunk of rows.

``` r
if (!dir_exists("chunks")) dir_create("chunks")

vroom_chunks <- function(loanbook, ald) {
  for (i in unique(loanbook$chunkid)) {
    matched <- match_name(filter(loanbook, chunkid == i), ald)
    if (nrow(matched) == 0L) next()
    matched %>% vroom_write(path("chunks", paste0(i, ".csv")))
  }
}

vroom_chunks(chunked, ald_full)
#> Warning: Found no match.

#> Warning: Found no match.

#> Warning: Found no match.

#> Warning: Found no match.

#> Warning: Found no match.

#> Warning: Found no match.

#> Warning: Found no match.

#> Warning: Found no match.

#> Warning: Found no match.

#> Warning: Found no match.

#> Warning: Found no match.

dir_ls("chunks") %>% head()
#> chunks/1.csv   chunks/10.csv  chunks/100.csv chunks/11.csv  chunks/12.csv  
#> chunks/13.csv
dir_ls("chunks") %>% tail()
#> chunks/94.csv chunks/95.csv chunks/96.csv chunks/97.csv chunks/98.csv 
#> chunks/99.csv

chunks <- dir_ls("chunks") %>% vroom()
#> Rows: 497
#> Columns: 16
#> Delimiter: "\t"
#> chr [12]: id_ultimate_parent, name_ultimate_parent, id_direct_loantaker, name_direct_loant...
#> dbl [ 4]: rowid, sector_classification_direct_loantaker, chunkid, score
#> 
#> Use `spec()` to retrieve the guessed column specification
#> Pass a specification to the `col_types` argument to quiet this message
chunks %>% count(sector)
#> # A tibble: 6 x 2
#>   sector          n
#>   <chr>       <int>
#> 1 automotive     98
#> 2 aviation       10
#> 3 cement         42
#> 4 oil and gas    68
#> 5 power         174
#> 6 shipping      105

chunks
#> # A tibble: 497 x 16
#>    rowid id_ultimate_par… name_ultimate_p… id_direct_loant… name_direct_loa…
#>    <dbl> <chr>            <chr>            <chr>            <chr>           
#>  1     1 UP15             Alpine Knits In… C294             Yuamen Xinneng …
#>  2     3 UP288            University Of I… C292             Yuama Ethanol L…
#>  3     1 UP33             Bhushan Energy … C274             Yosemite Unifie…
#>  4     1 UP33             Bhushan Energy … C274             Yosemite Unifie…
#>  5     2 UP5              Agni Steels Pri… C273             Yorkshire Windp…
#>  6     2 UP5              Agni Steels Pri… C273             Yorkshire Windp…
#>  7     3 UP190            Nagpur Tools Pv… C272             Yorkshire Water…
#>  8     3 UP190            Nagpur Tools Pv… C272             Yorkshire Water…
#>  9     1 UP8              Airbaltic        C4               Airbaltic       
#> 10     1 UP8              Airbaltic        C4               Airbaltic       
#> # … with 487 more rows, and 11 more variables:
#> #   sector_classification_system <chr>,
#> #   sector_classification_direct_loantaker <dbl>, chunkid <dbl>, id_2dii <chr>,
#> #   level <chr>, sector <chr>, sector_ald <chr>, name <chr>, name_ald <chr>,
#> #   score <dbl>, source <chr>
```

Cleanup

``` r
dir_ls("chunks") %>% file_delete()
```

## Pick the most important loans

Another option is to feed `match_name()` with data of only the loans
that make up most of the credit limit or outstanding credit limit, for
example, you may use only the largest loans that represent 80% of the
credit.

Let’s glimpse the columns that contain the pattern “loan\_size”:

``` r
lbk_full %>% 
  select(contains("loan_size")) %>% 
  glimpse()
#> Rows: 320
#> Columns: 4
#> $ loan_size_outstanding           <dbl> 225625, 301721, 410297, 233049, 40658…
#> $ loan_size_outstanding_currency  <chr> "EUR", "EUR", "EUR", "EUR", "EUR", "E…
#> $ loan_size_credit_limit          <dbl> 18968805, 19727961, 20811147, 1904286…
#> $ loan_size_credit_limit_currency <chr> "EUR", "EUR", "EUR", "EUR", "EUR", "E…
```

The `loan_size_*` values are comparable across rows because they are all
expressed in EURO:

``` r
lbk_full %>% 
  distinct(loan_size_outstanding_currency, loan_size_credit_limit_currency)
#> # A tibble: 1 x 2
#>   loan_size_outstanding_currency loan_size_credit_limit_currency
#>   <chr>                          <chr>                          
#> 1 EUR                            EUR
```

And the values in each row correspond to a unique loan:

``` r
nrow(lbk_full)
#> [1] 320
nrow(distinct(lbk_full, id_loan))
#> [1] 320
```

We can now arrange the data in descending order of the `loan_size_*`
columns, calculate the cumulative percent for each of them; and pick the
top loans that make up to 80% of the credit:

``` r
percent <- function(x) x / sum(x) * 100

top80 <- lbk_full %>% 
  arrange(desc(loan_size_credit_limit), desc(loan_size_outstanding)) %>% 
  mutate(
    cum_credit_limit = cumsum(percent(loan_size_credit_limit)),
    cum_outstanding  = cumsum(percent(loan_size_outstanding))
  ) %>% 
  filter(cum_credit_limit <= 80, cum_outstanding <= 80)

top80 %>% 
  select(id_loan, starts_with("cum_"), everything())
#> # A tibble: 207 x 21
#>    id_loan cum_credit_limit cum_outstanding id_direct_loant… name_direct_loa…
#>    <chr>              <dbl>           <dbl> <chr>            <chr>           
#>  1 L239               0.401           0.422 C164             Sanshui Beijian…
#>  2 L255               0.802           0.845 C110             Karnataka Power…
#>  3 L47                1.20            1.27  C257             Yolo County Flo…
#>  4 L81                1.60            1.69  C142             Nandi Roller Fl…
#>  5 L3                 2.00            2.11  C292             Yuama Ethanol L…
#>  6 L265               2.41            2.53  C20              Cloud Peak Ener…
#>  7 L88                2.81            2.95  C135             Nampower        
#>  8 L261               3.21            3.37  C22              Coronado Coal L…
#>  9 L84                3.61            3.79  C139             Mom and Pop Fam…
#> 10 L258               4.01            4.20  C13              Small Power Com…
#> # … with 197 more rows, and 16 more variables: id_intermediate_parent_1 <chr>,
#> #   name_intermediate_parent_1 <chr>, id_ultimate_parent <chr>,
#> #   name_ultimate_parent <chr>, loan_size_outstanding <dbl>,
#> #   loan_size_outstanding_currency <chr>, loan_size_credit_limit <dbl>,
#> #   loan_size_credit_limit_currency <chr>, sector_classification_system <chr>,
#> #   sector_classification_input_type <chr>,
#> #   sector_classification_direct_loantaker <dbl>, fi_type <chr>,
#> #   flag_project_finance_loan <chr>, name_project <lgl>,
#> #   lei_direct_loantaker <lgl>, isin_direct_loantaker <lgl>
```

The result is a dataset with considerably fewer rows that should use
less time and memory while capturing the main pattern.

``` r
round(nrow(top80) / nrow(lbk_full) * 100)
#> [1] 65
```

``` r
b <- bench::mark(
  check = FALSE,
  iterations = 30,
  all_loans = match_name(lbk_smaller, ald_demo),
  top80 = match_name(select(top80, crucial_lbk()), ald_demo)
)

autoplot(b)
```

![](working-with-big-data_files/figure-gfm/unnamed-chunk-22-1.png)<!-- -->
