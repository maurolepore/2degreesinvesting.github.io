########################## PACTA case study #################################

# the following is a run though example of how to run the complete PACTA analysis
# this case study uses mock data form  the r2dii.data package and functions from 
# the r2dii.match and r2dii.analysis package. 
# the matching process with vary from user to user and this example will not cover every 
# possible case you may come across. Rather it aims to demonstrate the process that a bank
# would need to follow to match their loan book as part of the PACTA work flow and final run the analysis.

########## Step 1 - install and load relevant packages 
install.packages("r2dii.data")
install.packages("r2dii.match")
install.packages("r2dii.analysis")
install.packages("dplyr")


library(r2dii.data)
library(r2dii.match)
library(r2dii.analysis)
library(dplyr)


########### step 1 - load data 

# read in asset level data set and loan book from .csv file (excel)
# note the spreadsheet must be in the same format with the same column names as the templates 
# provided in r2dii.data more info on this can be found in the table in "user guide 2. Prerequisites and preparing a loanbook"
# for this example mock data will be used from r2dii.data - when preforming this exercise for real the banks loan book should be used
# real asset level data is provided for free via asset resolution. 


# option 1 - note that with if the separator in your csv file is a ; then you must use read.csv2("...
# if it is a , then read.csv("...) will work. Note this is the case through out and also true of the function write.csv vs write.csv2
your_loanbook <- read.csv("C:/Users/44796/OneDrive/Documents/R/user guide/demo_lbk.csv", stingasfactor = FALSE)
your_ald <- read.csv("C:/Users/44796/OneDrive/Documents/R/user guide/demo_ald.csv", stingasfactor = FALSE)

#option 2
your_loanbook <- readr::read_csv("demo_lbk.csv", stingasfactor = FALSE)
your_ald <- readr::read_csv("demo_ald.csv", stingasfactor = FALSE)

########### Step 2 - match 

# giving matching file a name and use match_name function to match the lbk with the ald

# option 1 - this represents the most basic form of the match_name function. (recommended)

match_file <- r2dii.match::match_name(loanbook = "your_loanbook", ald = "your_ald")

# option 2 - this option allows you to tweak the arguments and do a more custom matching
# use ?match_name in the console to see the defaults and what each argument means
match_file <- r2dii.match::match_name(loanbook = "your_loanbook", ald = "your_ald", by_sector = TRUE, min_score = 0.8,
                                      method = "jW", p = 0.1, overwrite = NULL)


# export overwrite file to excel to overwrite companies or there sectors in the matching file
# this is used for advanced matching - it is not necessary that you do this. However if you 
# notice that a companies sector is incorrectly labels or you want to manually match a company to 
# one that you have found in the ald 

write.csv(r2dii.data::overwrite_demo, "filepath.....")

# overwrite matches in excel and then re import 
overwrite <- read.csv("...........overwriten_matches.csv")

# go back to line 51 and set overwrite = to your overwrite file eg "overwritten_matches.csv"
# continue to next step

# export match_file to excel to preform manual matching 

write.csv(match_file, "file path.....")

# open the csv file and preform manual verification using the score column 
# save a copy of the file with the verified matches. For a positive match the score column must = 1

# import the verified matches and any overwrite matches 

verified_matches <- read.csv("...........verified_match.csv")

# use prioritize to prioritize your matches 
# The validated dataset may have multiple matches per loan.
# Consider the case where a loan is given to "Acme Power USA", a subsidiary of "Acme Power Co.". 
# There may be both "Acme Power USA" and "Acme Power Co." in the ald, 
# and so there could be two valid matches for this loan. 
# To get the best match only, use prioritize() -- it picks rows where score is 1 and level per loan is of highest priority():
# by default this is the direct loan taker if you wish to set this to a different level you can do so 
# using the prioritize_level function

prioritzed_matches <- prioritize(verified_matches)



############ Step 3 - analysis 

# the r2dii.analysis package is broken down into 2 key functions 
# one for calculating results for the Auto, Fossil Fuel and Power sector
# r2dii.analysis::target_market_share() where results can be obtained at the portfolio level (weighted)
# and at the client level(unwighted)
# the second function is used to obtain results for the Steel and cement sector
# Please refer to the methodology documentation to find out the difference between the two

# before we run the analysis we need to import the scenario data

# for FF, Power and Auto - note 2dii provides scenarios that you can download 
# alternatively you can use your own, conditional on them being in the same format as the template provided
# in r2dii.data::scenario_demo_2020
scenario <- r2dii.data::scenario_demo_2020

# same as above but for the Steel and Cement sectors 
scenario_CO2 <- r2dii.data::co2_intensity_scenario_demo


# Run analysis at the portfolio level for Auto, Fossil Fuels and/or Power
portfolio_results <- r2dii.analysis::target_market_share(prioritzed_matches, your_ald, scenario,
                                                         region_isos = r2dii.data::region_isos)

# note if you want to run the analysis using the credit limit rather than the debt outstanding as the weighting 
# factor you can do so by setting  use_credit_limit = TRUE

#export results to csv

write.csv <- (portfolio_results, "..........")

# calculate results at the client level (un-weighted)

company_results <- r2dii.analysis::target_market_share(prioritzed_matches, your_ald,
                                                       scenario, by_company = TRUE)

#export results to csv

write.csv <- (company_results, "..........")

# calculate results of steel and cement sector - note company level results are not an option here.

port_result_sda <- r2dii.analysis::target_sda(prioritzed_matches, ald, sceanrio_co2)

#export results to csv

write.csv <- (port_result_sda, "..........")

######### - Finish 
