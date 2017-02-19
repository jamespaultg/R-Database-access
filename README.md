# R-Database-access
Run SQL queries on databases from within R script

I prefer to have the SQL query separately in a file(.SQL), so that it is easier to read and maintain.
I would like to update the parameters in the Query using the Infuser package, so that it is easier to see which parameters are requested in the SQL and also easy to pass values to them before executing the query.

The R script reads a Multiline SQL query(.SQL) and converts it into a single-line string - used logic suggested in http://stackoverflow.com/questions/2003663/import-multiline-sql-query-to-single-string/2003983#2003983 and tweaked to my needs
Used infuser package to override the SQL parameters in the SQL query
