[Coming soon...] 
***
Ruby Client for Gnip Historical Search API
***
==========================================


Many design details have not been implemented yet.  For example: (and now for the official TODO list)

+ [] No support yet for exercising the Search API with the command-line yet. Rather there are hard-coded settings in the code that will either be parsed out of the config file or passed in (like toDate and fromDate).
+ [] No support yet for encoding rules in JSON (or passed in via command-line).  Currently only YAML is supported.
+ [] No official notification of minutes that exceed "activities per request" limit (currently 500).


This was recently written to use Search API in order to collect the ~290,000 tweets around the recent flood here in Boulder.  I was working against the 30-day window since the flood and therefore focused on the algorithm to use minute counts to create data requests subject to the 500/tweets per requests yet deliver full-fidelity of the ~290,000 tweets.  And that works well.  Soon I need to flush out the many other details!




 ***Summary***

 Manages the activity data retrieval for one or more rules using the Gnip Search API, which makes available the last 30-days of Twitter data.  This client makes use of the Search API "counts per minute" method by adjusting data request periods in reference to the current limit of 500 activities per data request.  In this way the client can retrieve all tweets for a rule as long as there is no single minute with more than 500 activities. 




***Search API Description***

Search requests to the Historical Search API allow you to retrieve up to the last 500 results for a given timeframe in the last 30 days. It can be used to retrieve the most recent results for a high volume query, all results for a small time slice, or all of the results in the last 30 days for a low volume query. The Search endpoint is ideal for allowing users to search for recent data for a query or topic. Searches can be refined to any timeframe in the last 30 days to analyze the data in that given timeframe.



 Rules can be passed to the client in several ways:
 + One or more rules encoded in a JSON file and passed in via the command-line.
 + One or more rules encoded in a YAML file and passed in via the command-line.
 + Single rule passed in via the command-line.


Rule Tag support


Example usage:

$ruby ./search_api.rb -c "./SearchConfig.yaml" -r "./rules/mySearchRules.yaml"

$ruby ./search_api.rb -c "./SearchConfig.yaml" -r "./rules/mySearchRules.json"


search_api.rb [-r RULE] [-s SEARCH_URL] [-u USERNAME] [-p PASSWORD] [-c COUNT_ONLY] 





