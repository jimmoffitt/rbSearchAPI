[Coming soon...  Under major construction] 
***
***Ruby Client for Gnip Historical Search API***
***
==========================================

***Gnip Search API***

Search requests to the Historical Search API allow you to retrieve up to the last 500 results for a given timeframe in the last 30 days. It can be used to retrieve the most recent results for a high volume query, all results for a small time slice, or all of the results in the last 30 days for a low volume query. The Search endpoint is ideal for allowing users to search for recent data for a query or topic. Searches can be refined to any timeframe in the last 30 days to analyze the data in that given timeframe.

More information on the Search API can be found [HERE] (http://support.gnip.com/customer/portal/articles/1312908-search-api).

**Client Overview**

This client application helps manage the data retrieval from the Gnip Search API.  The client 


for one or more rules using the Gnip Search API, which makes available the last 30-days of Twitter data.  This client makes use of the Search API "counts per minute" method by adjusting data request periods in reference to the current limit of 500 activities per data request.  In this way the client can retrieve all tweets for a rule as long as there is no single minute with more than 500 activities.  

This Search API Ruby client supports submitting multiple rules.  A single rule can be passed in on the command-line, or a Rules file can be passed in and the client will make a Search API request for each rule. 

Rules can be passed to the client in several ways:
 + One or more rules encoded in a JSON file and passed in via the command-line.
 + One or more rules encoded in a YAML file and passed in via the command-line.
 + Single rule passed in via the command-line.

There is an option to have a gnip:matching_rules section added to the returned JSON payload.  In addition, Rule Tags can be specified and included in the matching_rules section. 

The client can also use the "counts" mechanism to return only the activity counts based on days, hours or minutes.  If counts are requested ("-l" command-line option, as in "look before you leap"), an array of count arrays are returned.

**Specifying Search Start and End Times**

If no "start" and "end" parameters are specified, the Search API defaults to 30-day requests. "Start" time defaults to 30 days ago from now, and "End" time default to "now". Start (-s) and end (-e) parameters can be specified in a variety of ways:

* Standard PowerTrack format, YYYYMMDDHHmm (UTC)
   * -s 201311070700 -e 201311080700 --> Search 2013-11-07 MST 
   * -s 201311090000 --> Search since 2013-11-09 00:00 UTC
* "YYYY-MM-DD HH:mm" (UTC, use double-quotes please)
   * 
   * -e 
* A combination of an integer and a character indicating "days" (#d), "hours" (#h) or "minutes" (#m).  Some examples:
   * -s 1d --> Start one day ago (i.e., search the last day)
   * -s 14d -e 7d --> Start 14 days ago and end 7 days ago (i.e. search the week before last)  
   * -s 6h --> Start six hours ago (i.e. search the last six hours)
     

At a minimum, the following parameters are needed to make a Search API request:

* Authentication details: username and password.  They can be provided on command-line or as part of a specified command-line.
* Account name or Search API URL.  If account name is provided, the URL is deter



**Background**

This was recently written to use Search API in order to collect the ~290,000 tweets around the recent flood here in Boulder.  I was working against the 30-day window since the flood and therefore focused on the algorithm to use minute counts to create data requests subject to the 500/tweets per requests yet deliver full-fidelity of the ~290,000 tweets. And that works well.  Soon I need to flush out the many other details!

Another feature that has been implemented is the ability to associate tags with the rules that are submitted and have those tags appended to the JSON payload.  The Search API does not support tags, and does not include the "matching_rules" metadata with the returned activities.  With my use-case I wanted this metadata, both matched rules and their tags, since I was blending Search API results in a MySQL database with other data collected in real-time and Historical PowerTrack.  Many of the queries I wanted to run on these data were going to be based on rules and tags.  Therefore, this client can append the rule and tag to the JSON payload in the standard gnip:matching_rules section. 

**Command-line options**

```
Usage: search_api [options]
    -c, --config CONFIG              Configuration file (including path) that provides account and download settings.
                                       Config files include username, password, account name and stream label/name.
    -u, --user USERNAME              User name for Basic Authentication.  Same credentials used for console.gnip.com.
    -p, --password PASSWORD          Password for Basic Authentication.  Same credentials used for console.gnip.com.
    -a, --address ADDRESS            Either Search API URL, or the account name which is used to derive URL.
    -n, --name NAME                  Label/name used for Stream API. Required if account name is supplied on command-line,
                                   which together are used to derive URL.
    -s, --start_date START           UTC timestamp for beginning of Search period.
                                         Specified as YYYYMMDDHHMM, "YYYY-MM-DD HH:MM" or use ##d, ##h or ##m.
    -e, --end_date END               UTC timestamp for ending of Search period.
                                      Specified as YYYYMMDDHHMM, "YYYY-MM-DD HH:MM"' or use ##d, ##h or ##m.
    -r, --rule RULE                  A single rule passed in on command-line, or a file containing multiple rules.
    -t, --tag TAG                    Optional. Gets tacked onto payload if included. Alternatively, rules files can contain tags.
    -l, --look                       "Look before you leap..."  Trigger the return of counts only.
    -d, --duration DURATION          The 'bucket size' for counts, minute, hour (default), or day
    -m, --max MAXRESULTS             Specify the maximum amount of data results.  10 to 500, defaults to 100.
    -b, --pub PUBLISHER              Defaults to Twitter, which currently is the only Publisher supported with Search.
    -h, --help                       Display this screen.
```

**Usage Examples**

[Narrative: can call by ] 

These examples pass in a configuration file that contains information like account name, username, and password:
* $ruby ./search_api.rb -c './myConfig.yaml' -r './rules/myRules.yaml' -s 14d
* $ruby ./search_api.rb -c './myConfig.yaml' -r './rules/myRules.yaml' -s 21d -e 14d 
* $ruby ./search_api.rb -c './myConfig.yaml' -r './rules/myRules.yaml' -s '2013-11-01 06:00' -e '2013-11-04 06:00'
* $ruby ./search_api.rb -c './myConfig.yaml' -r '(weather OR snow) profile_region:colorado' -s 7d 
* $ruby ./search_api.rb -c './myConfig.yaml' -l -r 'lang:en weather' 
* 

This example instead passes in credential details on the command-line:
* $ruby -u 'jmoffitt@gnipcentral.com' -p myPass -a jim -r gnip 






**Rule Tag support** 

[details to be documented]


---------------------------------------------
Many design details have not been implemented yet.  For example: (and now for the official TODO list)

+ [] There are many options in the Config file that are not available via the command-line.  That may be fine, and actually make sense.  Or not.  Need to review the options there, implement what is missing or remove those that need to be flushed.
+ [] Flush out support for exercising the Search API with the command-line. This client can be used in several ways:
   + Pass in a configuration file and a rules files.
   + Call with a configuration file, everything else (including a rule) on command-line.
   + Everything on command-line.
+ [] No official notification of minutes that exceed "activities per request" limit (currently 500).




