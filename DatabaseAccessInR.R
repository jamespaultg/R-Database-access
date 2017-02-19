############################################################
## Version : 1.0 | Date : 20171902 | JPG
## Program : Use R script to query from an Oracle database
##			 Tried packages RJDBC, ROracle and RODBC
##			 Note: ROracle seems to provide the best performance - https://www.r-bloggers.com/r-to-oracle-database-connectivity-use-roracle-for-both-performance-and-scalability/
##
## Reads a Multiline SQL query(.SQL) and converts it into a single-line string, used logic suggested in http://stackoverflow.com/questions/2003663/import-multiline-sql-query-to-single-string/2003983#2003983 and tweaked to my needs
## Uses infuser package to override the SQL parameters in the SQL query
##
###########################################################
# -------------  Package version compatibility ----------------------------------------------
# #Code tested against Package versions
# #readxl    readr    dplyr  infuser    RJDBC  ROracle    RODBC 
# #"0.1.1"  "1.0.0"  "0.5.0"  "0.2.5"  "0.2.5"  "1.3.1" "1.3.14" 

# Load required libraries
packages_used = c("readxl","readr","dplyr","infuser","RJDBC","ROracle","RODBC")
invisible(lapply(packages_used, require, character.only = TRUE))
# packages_used = c("readxl","readr","dplyr","infuser","RJDBC","ROracle","RODBC")
# # Package versions loaded currently
# sapply(packages_used,function(x) as.character(packageVersion(x)))

# -------------  Functions to read in the SQL query file and prepare it for processing in R ----------------------------------------------
LINECLEAN <- function(x) {
  x = gsub("\t+", "", x, perl=TRUE); # remove all tabs
  x = gsub("^\\s+", "", x, perl=TRUE); # remove leading whitespace
  x = gsub("\\s+$", "", x, perl=TRUE); # remove trailing whitespace
  x = gsub("[ ]+", " ", x, perl=TRUE); # collapse multiple spaces to a single space
  x = gsub("^[--]+.*$", "", x, perl=TRUE); # destroy any comments
  x = gsub(";", "", x, perl=TRUE); # destroy any semicolons
  x = gsub(":([A-Za-z_]+)","{{\\1}}",x, perl=TRUE) # replace sql query parameter ":parameter" to "{{parameter}}" (to use infuser to pass values - better readability)
  return(x)
}
# PRETTYQUERY is the filename of your formatted query in quotes, eg "myquery.sql"
# DIRPATH is the path to that file, eg "~/Documents/queries"
ONELINEQ <- function(PRETTYQUERY,DIRPATH) { 
  A <- readLines(paste0(DIRPATH,"/",PRETTYQUERY)) # read in the query to a list of lines
  B <- lapply(A,LINECLEAN) # process each line
  C <- Filter(function(x) x != "",B) # remove blank and/or comment lines
  D <- paste(unlist(C),collapse=" ") # paste lines together into one-line string, spaces between.
  return(D)
}
# TODO: add eof newline automatically to remove warning

# -------------  Provide the SQL query file  ----------------------------------------------
my_sql = ONELINEQ("queryresult Premiestand as-of particular date 20170102_TEST.sql","S:\\SC_S\\INF\\James\\Premie Overzicht\\Queries\\")

# Pass parameters to the Query
library(infuser)
library(lubridate)
variables_requested(my_sql, verbose = TRUE)  # To view parameters used in the Query
pijldatum_val = format(today(),"%d-%m-%Y") #To get current date in the format needed(dd-mm-ccyy)
#pijldatum_val = "'18-01-2017'"
#my_sql = gsub(":pijldate","{{pijldate}}",my_sql)
my_sql = infuse(my_sql, pijldate=pijldatum_val, transform_function = dplyr::build_sql)  # build_sql function helps to escape characters
my_sql # check if the correct value is set to the variables

# -------------  use RJDBC  ----------------------------------------------
# RJDBC works fine
library(RJDBC)
# set the driver
drv <- JDBC("oracle.jdbc.OracleDriver",classPath="C:/oracle32/product/11.2.0/client_1/jdbc/lib/ojdbc5.jar", " ")
# connect to the database
# dbConnect syntax
# con <- dbConnect(drv, "jdbc:oracle:thin:@//ipaddress or hostname:port/SID", "username", "password")
# Port is usally 1521
queryresult = dbGetQuery(con, my_sql)
head(queryresult)
# Close the database connection always!
dbDisconnect(con)

# -------------  use ROracle  ----------------------------------------------
# Installing ROracle if not already installed
# check if environment variables OCI_INC, OCI_LIB64 are persent. If not, use the following(be sure to provide the correct location)
#Sys.setenv(OCI_INC = "C:\\oracle64\\product\\11.2.0\\client_1\\oci\\include")
#Sys.setenv(OCI_LIB64 = "C:\\oracle64\\product\\11.2.0\\client_1\\bin")
# install.packages("ROracle")
# Errors if any, consult this page http://nevilleandrade.blogspot.co.uk/2015/03/installing-and-using-roracle-in-r.html
library(ROracle)

# Make connection
drv = dbDriver("Oracle")
DBname = "(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=hostname)(PORT=1521))(CONNECT_DATA=(SID=SID_name)))"
con = dbConnect(drv, "USER_NAME", "PASSWORD", dbname = DBname)

# Select some data (try to avoid downloading entire tables)
queryresult = dbGetQuery(con, my_sql)
head(queryresult)

# Close the database connection always!
dbDisconnect(con)

# -------------  use RODBC  ----------------------------------------------
library(RODBC)
myconn <-odbcConnect("SID_name", uid="USER_NAME", pwd="PASSWORD",believeNRows=FALSE)
# Display all the schemas in the database (optional)
sqlQuery(myconn,"select username from dba_users")
# Check that connection is working (Optional)
odbcGetInfo(myconn)
# Find out what tables are available (Optional)
Tables <- sqlTables(myconn, schema="SCHEMA_NAME")
# Query the database and put the results into the data frame "dataframe"
dataframe <- sqlQuery(myconn, my_sql)
##  Note: This results in the below error
#Error in odbcQuery(channel, query, rows_at_time) : 
#  'Calloc' could not allocate memory (214748364800 of 1 bytes)
#In addition: Warning messages:
#1: In odbcQuery(channel, query, rows_at_time) :
#  Reached total allocation of 8056Mb: see help(memory.size)
#2: In odbcQuery(channel, query, rows_at_time) :
#  Reached total allocation of 8056Mb: see help(memory.size)
close(myconn)

# -------------  Further work  ----------------------------------------------
# check why RODBC fails
# Two issues with the SQL clean-up script
# 1.If the line starts with a minus sign, for example '-NVL' then that line is skipped
# 2. If there are comment after the SQL statement, then the statements in the next line following the comments are ignored,
# so if you want to have inline comments then it should be the PL/SQL format '/*...*/'

# -------------  References  ----------------------------------------------
# http://stackoverflow.com/questions/2003663/import-multiline-sql-query-to-single-string/2003983#2003983
# Infuser package - https://github.com/Bart6114/infuser
# https://www.r-bloggers.com/connecting-r-to-an-oracle-database-with-rjdbc/
# https://www.r-bloggers.com/easier-database-querying-with-r/
# SQL injection - https://cran.r-project.org/web/packages/RODBCext/vignettes/Parameterized_SQL_queries.html
