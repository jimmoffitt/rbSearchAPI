***
***Ruby Client for Gnip 30-day Search API***
***

***Gnip Search API***

Search requests to the Historical Search API allow you to retrieve all Tweets for a given query from the previous 30 days. It can be used to retrieve the most recent results for a high volume query, all results for a small time slice, or all of the results in the last 30 days using pagination techniques. The Search endpoint is ideal for allowing users to search for recent data for a query or topic. Searches can be refined to any timeframe in the last 30 days to analyze the data in that given timeframe.

More information on the Search API can be found [HERE] (http://support.gnip.com/customer/portal/articles/1312908-search-api).

***So, what does this Gnip Search API client do?***

This Ruby client is a wrapper around the 30-day Search API. It was written to be a flexible tool for managing Search API requests. Here are some of the features:

* Rules can be submitted in a variety of ways: multiple rules from a JSON or YAML file or a single rule passed in via the command-line.  
* Results for the entire request period will be returned.  The script manages a pagination process that makes multiple requests if necessary.  
* Data can be provided in three ways: exported as files, written to a database, or written to standard out.
* Activity counts can be returned by using the "-l" parameter (as in 'look before you leap').  Counts by minute, by hour, or by day can be returned.
* Appends gnip:matching_rules metadata to the returned JSON payload.  If rules include tags, these metadata are appended as well.
* Search start and end time can be specified in several ways: standard PowerTrack timestamps (YYYYMMDDHHMM), 
  ISO 8061/Twitter timestamps (2013-11-15T17:16:42.000Z), as "YYYY-MM-DD HH:MM", and also with simple notation indicating the number of minutes (30m), hours (12h) and days (14d).
* Configuration and rule details can be specified by passing in files or specifying on the command-line, or a combination of both.  Here are some quick example:
  * Using configuration and rules files, requesting 30 days: $ruby search_api.rb -c "./myConfig.yaml" -r "./myRules.json"
  * Using configuration and rules in files, requesting last 7 days: $ruby search_api.rb -c "./myConfig.yaml" -r "./myRules.json" -s 7d
  * Specifying everything on the command-line: $ruby search_api.rb -u me@there.com -p password -a http://search.gnip.com/accounts/jim/search/prod.json -r "profile_region:colorado snow" -s 7d 


**Background**

This was started to use Search API in order to collect the ~290,000 tweets around the recent flood here in Boulder. There were about 30 rules/filters I wanted to search with using hashtags, weather terms and local agency names. I was working against the 30-day window since the flood and therefore focused on the algorithm to use minute counts to create data requests subject to the 500/tweets per request yet deliver full-fidelity of the ~290,000 tweets. And that worked well. 

Another feature that has been implemented is the ability to associate tags with the rules that are submitted and have those tags appended to the JSON payload.  The Search API does not support tags, and does not include the "matching_rules" metadata with the returned activities.  With my use-case I wanted this metadata, both matched rules and their tags, since I was blending Search API results in a MySQL database with other data collected in real-time and Historical PowerTrack.  Many of the queries I wanted to run on these data were going to be based on rules and tags.  Therefore, this client can append the rule and tag to the JSON payload in the standard gnip:matching_rules section. 


**Client Overview**

This client application helps manage the data retrieval from the Gnip 30-day Search API. This client makes use of the Search API "counts per minute" method by adjusting data request periods in reference to the current limit of 500 activities per data request.  In this way the client can retrieve all tweets for a rule as long as there is no single minute with more than 500 activities.  

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
   * -s 201311070700 -e 201311080700 --> Search 2013-11-07 MST. 
   * -s 201311090000 --> Search since 2013-11-09 00:00 UTC.
* A combination of an integer and a character indicating "days" (#d), "hours" (#h) or "minutes" (#m).  Some examples:
   * -s 1d --> Start one day ago (i.e., search the last day)
   * -s 14d -e 7d --> Start 14 days ago and end 7 days ago (i.e. search the week before last)  
   * -s 6h --> Start six hours ago (i.e. search the last six hours) 
* "YYYY-MM-DD HH:mm" (UTC, use double-quotes please)
   * -s "2013-11-04 07:00" -e "2013-11-07 06:00" --> Search 2013-11-04 and 2013-11-05 MST.
* "YYYY-MM-DDTHH:MM:SS.000Z" (ISO 8061 timestamps as used by Twitter, in UTC)
   * -s 2013-11-20T15:39:31.000Z --> Search beginning at 2013-11-20 22:39 MST (note that seconds are dropped).


**Command-line options**

At a minimum, the following parameters are needed to make a Search API request:

* Authentication details: username and password.  They can be provided on command-line or as part of a specified configuration file.
* Account and stream names or Search API URL.  If account and stream names are provided, the URL generated from that information. 
* At least one rule/filter. A single rule can be passed in on the command-line, or one or more passed in from a rules file.
* There are three output options: activities can simply returned from script as "standard out", written to data files, or written to a database.  If not configuration file is used, data will written to standard out.  Otherwise you can specify your output preference in the config file.  If writing to data files or a database you must specify the details in the config file (i.e. output folder, database connection details).


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
                                        Specified as YYYYMMDDHHMM, "YYYY-MM-DD HH:MM", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -r, --rule RULE                  A single rule passed in on command-line, or a file containing multiple rules.
    -t, --tag TAG                    Optional. Gets tacked onto payload if included. Alternatively, rules files can contain tags.
    -o, --outbox OUTBOX              Optional. Triggers the generation of files and where to write them.
    -z, --zip                        Optional. If writing files, compress the files with gzip.
    -l, --look                       "Look before you leap..."  Trigger the return of counts only.
    -d, --duration DURATION          The 'bucket size' for counts, minute, hour (default), or day
    -m, --max MAXRESULTS             Specify the maximum amount of data results.  10 to 500, defaults to 100.
    -b, --pub PUBLISHER              Defaults to Twitter, which currently is the only Publisher supported with Search.
    -h, --help                       Display this screen.

```

**Configuration Files**

Many script and Search API options can be specified in a configuration (YAML) file as an alternative to passing in settings via the command-line.  Please note that if you are writing data to a database you must specify the database details in a configuration file.

```yaml
#Account details.
account:
  account_name: my_account_name  #Used in URL for Gnip APIs.
  user_name: me@mycompany.com
  password_encoded: PaSsWoRd_EnCoDeD  #At least some resemblance of security. Generated by "base64" Ruby Gem.
  #password: PlainTextPassword  #Use this is you want to use plain text, and comment out the encoded entry above.

#Search API configuration details:

search:
  label: prod
  write_rules: true
  compress_files: true
  storage: files #options: files, database, standard_out --> Store activities in local files, in database. or print to system out?
  out_box: ./search_out #Folder where retrieved data goes.
  
#Note that if you want to write to a database, the connection details must be specified in this file.
database:
  host: 127.0.0.1
  port: 3306
  #Note: currently all PowerTrack example clients share a common database schema.
  schema: power-track_development
  user_name: user
  password_encoded:
  #password: test
  type: mysql

```


**Rules Files**

Multiple rules can be specified in JSON or YAML files.  Below is an example of each.  Note that the use of tags are optional.  While the Search API does not support tags or providing gnip:matching_rules metadata, this script will append that information to the JSON payloads.  Also note that an individual rule can be specified on the command-line. 

JSON rules file:
```json
{
  "rules" :
    [
        {
          "value" : "snow profile_region:colorado",
          "tag" : "ski_biz"
        },
        {
          "value" : "snow profile_region:utah",
          "tag" : "ski_biz"
        },
        {
          "value" : "rain profile_region:washington",
          "tag" : "umbrellas"
        }
    ]
}
```
YAML rules file:
```yaml
rules:
  - value  : "snow profile_region:colorado"
    tag    : ski_biz
  - value  : "snow profile_region:utah"
    tag    : ski_biz
  - value  : "rain profile_region:washington"
    tag    : umbrellas
```


**Rule Tag support** 

Rules files can specify tags, and these will be included in the gnip:matching_rules metadata that this script appends to the JSON payload. Also, if passing in an individual rule via the command-line, a tag can also be provided:

-r "snow profile_region:colorado" -t ski-biz

**Usage Examples**

This Ruby script was designed to be flexible in its usage.  So, below are some usage examples:  

These examples pass in a configuration file that contains information like account name, username, and password and other settings:
* $ruby search_api.rb -c './myConfig.yaml' -r './rules/myRules.yaml' -s 14d
* $ruby ./search_api.rb -c './myConfig.yaml' -r './rules/myRules.yaml' -s 21d -e 14d 
* $ruby ./search_api.rb -c './myConfig.yaml' -r './rules/myRules.yaml' -s '2013-11-01 06:00' -e '2013-11-04 06:00'
 
This example passes in an individual rule, and asks for the past 7 days:
* $ruby search_api.rb -c './myConfig.yaml' -r '(weather OR snow) profile_region:colorado' -s 7d

This example asks for 30-day hourly counts for the specified rule:
* $ruby search_api.rb -c './myConfig.yaml' -r 'lang:en weather' -l -d hour 

This example instead passes in credential details on the command-line:
* $ruby search_api.rb -u 'me@there.com' -p myPass -a myAccount -n prod -r 'lang:en weather'
 
This example specifies the Search API end-point, and thus does not need to include account and stream label (name) information:
* $ruby search_api.rb -u 'me@there.com' -p myPass -a http://search.gnip.com/accounts/myAccount/search/prod.json -r 'lang:en weather'




