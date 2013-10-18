#Makes minute count request, then navigates those results, consolidating minute counts up to 500 for data requests.
#Need to notify about minutes with more than 500 matches.



#TODO: load up rules, and loop through them.
#TODO: implement writing to database or to files.

#TODO: If a rule tag is supplied, we should tack that onto the activity payload.
#TODO: mode to just get counts.
#TODO: command-line support for making single calls, both counts and data.
#TODO: add up collected activities and compare to count summation.

class PtSearch

    require "json"
    require "yaml"          #Used for configuration files.
    require "base64"
    require "fileutils"
    require "zlib"
    require "time"

    #PowerTrack classes
    require_relative "./pt_restful"
    require_relative "./pt_database"
    require_relative "./pt_rules"
    #include PtCommon

    API_ACTIVITY_LIMIT = 500 #Limit on the number of activity IDs per Rehydration API request.
    API_DAYS_OLD_LIMIT = 30

    attr_accessor :http,   #need a HTTP object to make requests of.
                  :urlSearch, :urlCount,  #Search uses two different end-points...

                  :account_name, :user_name, :password, #System authentication.
                  :publisher, :product, :label,

                  :rules,  #rules object.
                  :rules_file, #YAML (or JSON?) file with rules.
                  :request_rule, #When working with just one rule?
                  :write_rules, #Append rules/tags to collected JSON, if it is normalized AS format.
                  :compressed_files,

                  :interval,
                  :max_results,
                  :from_date, :to_date,   #'Study' period.
                  :request_from_date, :request_to_date, #May be breaking up 'study' period into separate smaller periods.
                  :count_total,  #total of individual bucket counts.

                  :storage,
                  :in_box, :out_box

    def initialize(config_file)
        #class variables.
        @@base_url = "https://search.gnip.com/accounts/"

        #Initialize stuff.

        #Defaults.
        @publisher = "twitter"
        @product = "search"
        @interval = "minute"
        @max_results = API_ACTIVITY_LIMIT

        get_system_config(config_file)  #Load the oHistorical PowerTrack account details.

        @rules = PtRules.new

        #Set up a HTTP object.
        @http = PtRESTful.new  #Historical API is REST based (currently).
        @http.publisher = @publisher
        @http.user_name = @user_name  #Set the info needed for authentication.
        @http.password_encoded = @password_encoded  #HTTP class can decrypt password.

        @urlSearch = @http.getSearchURL(@account_name, @label)
        @urlCount =  @http.getSearchCountURL(@account_name, @label)

        #Default to the "search" url.
        @http.url = @urlSearch  #Pass the URL to the HTTP object.
    end

    #Load in the configuration file details, setting many object attributes.
    def get_system_config(config_file)

        config = YAML.load_file(config_file)

        #Config details.
        @account_name = config["account"]["account_name"]
        @user_name  = config["account"]["user_name"]
        @password_encoded = config["account"]["password_encoded"]

        if @password_encoded.nil? then  #User is passing in plain-text password...
            @password = config["config"]["account"]
            @password_encoded = Base64.encode64(@password)
        end

        @label = config["search"]["label"]

        #User-specified in and out boxes.
        @in_box = checkDirectory(config["search"]["in_box"])
        #Managing request lists that have been processed.
        @in_box_completed = checkDirectory(config["search"]["in_box_completed"])
        @out_box = checkDirectory(config["search"]["out_box"])

        @storage = config["search"]["storage"]

        @write_rules = config["search"]["write_rules"]
        @compress_files = config["search"]["compress_files"]

        if @storage == "database" then #Get database connection details.
            db_host = config["database"]["host"]
            db_port = config["database"]["port"]
            db_schema = config["database"]["schema"]
            db_user_name = config["database"]["user_name"]
            db_password  = config["database"]["password"]

            @datastore = PtDatabase.new(db_host, db_port, db_schema, db_user_name, db_password)
            @datastore.connect
        end
    end

    def get_search_rules
        if !@rules_file.nil then
            @rules.loadRulesYAML(@rules_file)
        end
    end


    #-----------------------------------------------------
    #To be ported to a separate 'common' module
    #Confirm a directory exists, creating it if necessary.
    def checkDirectory(directory)
        #Make sure directory exists, making it if needed.
        if not File.directory?(directory) then
            FileUtils.mkpath(directory) #logging and user notification.
        end
        directory
    end

    def getDateString(time)
        return time.year.to_s + sprintf('%02i',time.month) + sprintf('%02i',time.day) + sprintf('%02i',time.hour) + sprintf('%02i',time.min)
    end

    def getDateObject(time_string)
        time = Time.new
        time = Time.parse(time_string)
        return time
    end

    #-----------------------------------------------------



    '''
    Process this single API response.
    May have up to ID_API_REQUEST_LIMIT activities to handle.
    Depending on the configuraion, this method writes the activity data to the out_box or to the database.

    This is where you would implement any other datastore strategy.
    '''
    def process_response(response)

        response_hash = JSON.parse(response) #Converting JSON payload to hash

        response_hash.each do |activity|
            if activity["available"] then
                #p "Activity is available..."
                #Grab activity ID for file name
                if @storage == "files" then
                    File.open(@out_box + "/" + activity["id"] + ".json", "wb") do |new_file|
                        new_file.write(activity["content"].to_json)  #Write as JSON.
                    end
                else
                    @datastore.storeActivity(activity["content"].to_json)  #Pass in as JSON.
                end
            else
                handleNotAvailable(activity)
            end
        end
    end

    def get_count_total(count_response)

        count_total = 0

        contents = JSON.parse(count_response)
        results = contents["results"]
        results.each do |result|
            #p  result["count"]
            count_total = count_total + result["count"]
        end

        @count_total = count_total

    end

    def get_counts(rule, start_time, end_time, interval)

        @count_total = 0
        @http.url = @urlCount
        data = build_count_request(rule, start_time, end_time, interval)
        response = @http.POST(data)
        p response.body
        @count_total = get_count_total(response.body)

        #Parse response.body and build ordered array.
        temp = JSON.parse(response.body)

        bins = temp["results"]

        return bins

    end

    def get_file_name(rule, start_time, end_time)
        rule_str = rule.gsub(/[^[:alnum:]]/, "")[0..9]
        filename = "#{rule_str}_#{start_time}_#{end_time}"
        return filename
    end

    def append_rules(response,rule,tag)

        #Build the "matching_rules" hash that will be added to payload hash.
        matching_rules = {}
        matching_rules["value"] = rule
        matching_rules["tag"] = tag

        #Load activities into a hash.
        activities = []
        activities = response["results"]

        activities_updated = []

        if activities.nil? then
            p "No activities?"
        end

        #Tour activities, adding matching rules to "gnip" key.
        activities.each do |activity|
            activity["gnip"]["matching_rules"] = matching_rules
            activities_updated << activity
        end

        #Explicitly kill activities hash.
        activities = nil

        #Recreate, add a "results" root tag, then add the updated activities.
        activities = []
        activities = {"results" => activities_updated}

        return activities
    end

    def get_data(rule,start_time,end_time,tag)

        if start_time == end_time then
            p "BUG ALERT!"
        end

        @http.url = @urlSearch
        data = build_data_request(rule,start_time,end_time)

        response = @http.POST(data)
        p "Getting data based on: #{data}"

        #Prepare to convert Search API JSON to hash.
        api_response = []
        api_response = JSON.parse(response.body)

        if !(api_response["error"] == nil) then
            p "Handle error!"
        end

        #Add rules/tags to if configured to #TODO: and if AS format
        if @write_rules then
            api_response = append_rules(api_response, rule, tag)
        end

        #TODO: do something with the data!
        if @storage == "files" then #write the file.

            p "Storing Search API data in a file..."

            filename = ""
            filename = get_file_name(rule, start_time, end_time)

            if @compress_files then
                File.open("#{@out_box}/#{filename}.json.gz",'w') do |f|
                    gz = Zlib::GzipWriter.new(f,level=nil,strategy=nil)
                    gz.write api_response.to_json
                    gz.close
                end
            else
                File.open("#{@out_box}/#{filename}.json","w") do |new_file|
                    new_file.write(api_response.to_json)
                end
            end
        else #store in database.
            p "Storing Search API data in database..."

            results = []
            results = api_response["results"]


            #if !(results == null) then
            #    results = []
            #    results = JSON.parse(api_response)
            #    results = results["results"]
            #end

            results.each do |activity|

                p activity

                @datastore.storeActivity(activity.to_json)


            end
        end

    end

    def make_end_time(start_time, interval)

        #Convert to date object.
        time = getDateObject(start_time)

        #Add interval. Adding seconds...
        if interval == "day" then
            time = time + (24 * 60 * 60)

        elsif interval == "hour" then
            time = time + (60 * 60)

        elsif interval == "minute" then
            time = time + (60)
        end

        return getDateString(time)
    end

    #Builds a hash and generates a JSON string.
    #Defaults:
    #@interval = "hour"   #Set in constructor.
    #@max_results = API_ACTIVITY_LIMIT   #Set in constructor.
    #@publisher = "twitter"  #Set in constructor.

    def build_request(rule, from_date=nil, to_date=nil)
        request = {:publisher => @publisher, :query => rule}

        if !from_date.nil?
            request[:fromDate] = from_date
        end

        if !to_date.nil?
            request[:toDate] = to_date
        end

        return request
    end

    def build_count_request(rule, from_date=nil, to_date=nil, interval=nil)

        request = build_request(rule,from_date, to_date)

        if !interval.nil?
            request[:bucket] = interval
        else
            request[:bucket] = @interval
        end

        return JSON.generate(request)
    end

    def build_data_request(rule, from_date=nil, to_date=nil, max_results=nil)

        request = build_request(rule,from_date, to_date)


        if !max_results.nil?
            request[:maxResults] = max_results
        else
            request[:maxResults] = @max_results
        end

        return JSON.generate(request)
    end



    def process_data(rule, start_time, end_time, interval, tag=nil)
        #Get counts based on passed-in interval

        p "Getting '#{interval}' counts for #{start_time} -to- #{end_time} "
        bins = []
        bins = get_counts(rule, start_time, end_time, interval)

        p "Have #{@count_total} activities for rule: #{rule}"

        if @count_total == 0 then
            return
        end


        #Initialize some stuff.
        start_time = bins[0]["timePeriod"]
        end_time = bins[1]["timePeriod"]
        count_total = 0

        #Walk the bins...
        bins.each_with_index do | bin, index |


            #if index > 10590 then
            #    p "debug stop"
            #
            #end


            #p "Looping '#{interval}' bins, index = #{index}, have #{bin["count"]} activities"

            #This handles the case where a single bin exceeds the limit.
            #TODO: largely untested, and not really needed if you just start with interval = "minute" (no need to step
            # down to shorter duration buckets)
            if bin["count"] > API_ACTIVITY_LIMIT then
                #Logic for triggering counts for "next level down": day --> hour --> minute
                if interval == "minute" then
                    p "NOTIFY about data fidelity..."

                elsif interval == "hour" then
                    process_data(rule, bin["timePeriod"], bins[index+1]["timePeriod"], "minute")

                elsif interval == "day" then
                    process_data(rule, bin["timePeriod"], bins[index+1]["timePeriod"], "hour")
                end

            else

                #Otherwise, we are under the limit, so proceed.
                count_total = count_total + bin["count"]

                #This handles the case where adding the next bin will exceed the limit
                if (index+1 == bins.length) or (count_total + bins[index+1]["count"]) > API_ACTIVITY_LIMIT then #Stop and process...
                    if count_total > 0 then
                        p "#{rule} --> Going to get #{count_total} activities for #{start_time} to #{end_time} ..."

                        if start_time == end_time then
                            p "BUG ALERT!"
                            end_time = bins[index+1]["timePeriod"]   #TODO - this is a kludge, need to find source of problem...
                        end

                        get_data(rule, start_time, end_time, tag)
                        count_total = 0 #TODO: well, if no error occurred!
                    end
                    #Reset start time.
                    if index < bins.length then
                        start_time = end_time
                        end_time = bins[index]["timePeriod"]
                    else
                        p 'TODO: remove: We are done here'
                    end
                else
                    #Not advancing start time.
                    #Advance end time.
                    if (index + 1) == bins.length then
                        end_time = make_end_time(start_time, interval)
                    else
                        end_time = bins[index+1]["timePeriod"]
                    end
                end
            end
        end #bins loop.
    end #process_data.
end #pt_stream class.


#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

    require 'optparse'
    OptionParser.new do |o|
        o.on('-c CONFIG') { |config| $config = config}
        o.parse!
    end

    if $config.nil? then
        $config = "./PowerTrackConfig_private.yaml"  #Default
    end

    #Create a Rehyrdation PowerTrack object, passing in an account configuration file.
    p "Creating PT Search object with config file: " + $config
    oSearch = PtSearch.new($config)

    '''
    rule = "#longmontflood"
    start_time = "201309100600"
    end_time = "201309240600"
    interval = "minute"
    oSearch.process_data(rule,start_time,end_time,interval)
    '''

    oSearch.rules_file = "./rules/boulderflood.yaml"
    #oSearch.get_search_rules()
    oSearch.rules.loadRulesYAML(oSearch.rules_file)


    #start_time = "201309080600"
    #end_time = "201309130600"
    #end_time = "201310030600"

    start_time = "201309130500"
    end_time = "201310090600"

    interval = "minute"
    oSearch.rules.rules.each do |rule|
        p "Getting activities for rule: #{rule["value"]}"
        oSearch.process_data(rule["value"],start_time,end_time,interval,rule["tag"])
    end


    #rule = "#boulderflood"
    #Let go get a count for a rule.  Currently defaults to hourly counts.
    #counts_json = oSearch.getActivityCounts(rule)


    #convert to array
    #counts = Array.new

    #counts = JSON.parse(counts_json["results"])

    #counts.each { |count|

    #    p count

    #}

    p "Exiting"

end
