class PtSearch

    require "json"
    require "yaml" #Used for configuration files.
    require "base64"
    require "fileutils"
    require "zlib"
    require "time"

    #PowerTrack classes
    require_relative "./pt_restful"
    require_relative "./pt_database"
    require_relative "./pt_rules"

    API_ACTIVITY_LIMIT = 500 #Limit on the number of activity IDs per Rehydration API request, can be overridden.
    API_DAYS_OLD_LIMIT = 30

    attr_accessor :http, #need a HTTP object to make requests of.
                  :urlSearch, :urlCount, #Search uses two different end-points...

                  :account_name, :user_name,
                  :password, :password_encoded, #System authentication.
                  :publisher, :product, :label,

                  :rules, #rules object.
                  :rules_file, #YAML (or JSON?) file with rules.
                  :write_rules, #Append rules/tags to collected JSON, if it is normalized AS format.
                  :compress_files,

                  :interval,
                  :max_results,
                  :from_date, :to_date, #'Study' period.
                  :request_from_date, :request_to_date, #May be breaking up 'study' period into separate smaller periods.
                  :count_total, #total of individual bucket counts.

                  :storage,
                  :in_box, :out_box,

                  :request_timestamp

    def initialize()
        #class variables.
        @@base_url = "https://search.gnip.com/accounts/"

        #Initialize stuff.

        #Defaults.
        @publisher = "twitter"
        @product = "search"
        @interval = "minute"
        @max_results = API_ACTIVITY_LIMIT
        @out_box = "./"
        @request_timestamp = Time.now - 1

        @rules = PtRules.new

        #Set up a HTTP object.
        @http = PtRESTful.new #Historical API is REST based (currently).
    end

    #Attempts to determine if password is base64 encoded or not.
    #Uses this recipe: http://stackoverflow.com/questions/8571501/how-to-check-whether-the-string-is-base64-encoded-or-not
    def password_encoded?(password)
        reg_ex_test = "^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{4}|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)$"

        if password =~ /#{reg_ex_test}/ then
            return true
        else
            return false
        end
    end

    def password_encoded
        Base64.encode64(@password) unless @passwork.nil?
    end

    #Load in the configuration file details, setting many object attributes.
    def get_system_config(config_file)

        config = YAML.load_file(config_file)

        #Config details.

        #Parsing account details if they are provided in file.
        if !config["account"].nil? then
            if !config["account"]["account_name"].nil? then
                @account_name = config["account"]["account_name"]
            end

            if !config["account"]["user_name"].nil? then
                @user_name = config["account"]["user_name"]
            end

            if !config["account"]["password"].nil? or !config["account"]["password_encoded"].nil? then
                @password_encoded = config["account"]["password_encoded"]

                if @password_encoded.nil? then #User is passing in plain-text password...
                    @password = config["account"]["password"]
                    @password_encoded = Base64.encode64(@password)
                end
            end
        end

        if !config["search"]["label"].nil? then #could be provided via command-line
            @label = config["search"]["label"]
        end

        #User-specified in and out boxes.
        #@in_box = checkDirectory(config["search"]["in_box"])
        #Managing request lists that have been processed.
        #@in_box_completed = checkDirectory(config["search"]["in_box_completed"])

        @storage = config["search"]["storage"]

        begin
            @out_box = checkDirectory(config["search"]["out_box"])
        rescue
            @out_box = "./"
        end

        begin
            @compress_files = config["search"]["compress_files"]
        rescue
            @compress_files = false
        end

        #@write_rules = config["search"]["write_rules"]

        if @storage == "database" then #Get database connection details.
            db_host = config["database"]["host"]
            db_port = config["database"]["port"]
            db_schema = config["database"]["schema"]
            db_user_name = config["database"]["user_name"]
            db_password = config["database"]["password"]

            @datastore = PtDatabase.new(db_host, db_port, db_schema, db_user_name, db_password)
            @datastore.connect
        end
    end

    def set_http
        @http.publisher = @publisher
        @http.user_name = @user_name #Set the info needed for authentication.
        @http.password_encoded = @password_encoded #HTTP class can decrypt password.

        @urlSearch = @http.getSearchURL(@account_name, @label)
        @urlCount = @http.getSearchCountURL(@account_name, @label)

        #Default to the "search" url.
        @http.url = @urlSearch #Pass the URL to the HTTP object.
    end


    def get_search_rules
        if !@rules_file.nil then #TODO: Add JSON option.
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

    def get_date_string(time)
        return time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)
    end

    def get_date_object(time_string)
        time = Time.new
        time = Time.parse(time_string)
        return time
    end

    def numeric?(object)
        true if Float(object) rescue false
    end

    #Takes a variety of string inputs and returns a standard PowerTrack YYYYMMDDHHMM timestamp string.
    def set_date_string(input)

        now = Time.new
        date = Time.new

        #Handle minute notation.
        if input.downcase[-1] == "m" then
            date = now - (60 * input[0..-2].to_f)
            return get_date_string(date)
        end

        #Handle hour notation.
        if input.downcase[-1] == "h" then
            date = now - (60 * 60 * input[0..-2].to_f)
            return get_date_string(date)
        end

        #Handle day notation.
        if input.downcase[-1] == "d" then
            date = now - (24 * 60 * 60 * input[0..-2].to_f)
            return get_date_string(date)
        end

        #Handle PowerTrack format, YYYYMMDDHHMM
        if input.length == 12 and numeric?(input) then
            return input
        end

        #Handle "YYYY-MM-DD 00:00"
        if input.length == 16 then
            return input.gsub!(/\W+/, '')
        end

        #Handle ISO 8601 timestamps, as in Twitter payload "2013-11-15T17:16:42.000Z"
        if input.length > 16 then
            date = Time.parse(input)
            return get_date_string(date)
        end

        return 'Error, unrecognized timestamp.'

    end

    #-----------------------------------------------------

    '''
    Process this single API response.
    May have up to ID_API_REQUEST_LIMIT activities to handle.
    Depending on the configuration, this method writes the activity data to the out_box or to the database.

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
                        new_file.write(activity["content"].to_json) #Write as JSON.
                    end
                else
                    @datastore.storeActivity(activity["content"].to_json) #Pass in as JSON.
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

        results = {}
        @count_total = 0
        @http.url = @urlCount
        data = build_count_request(rule, start_time, end_time, interval)

        if (Time.now - @request_timestamp) < 1 then
            sleep 1
        end
        @request_timestamp = Time.now

        response = @http.POST(data)
        #p response.body
        @count_total = get_count_total(response.body)

        results['total'] = @count_total

        #Parse response.body and build ordered array.
        temp = JSON.parse(response.body)
        results['results'] = temp['results']

        return results
    end

    # TODO: needs to check for existing file name, and serialize if needed.
    # Payloads are descending chronological, to first timestamp is end_time, last is start_time.  Got it?
    def get_file_name(rule, results)

        #Get start_time of this response payload.
        time = Time.parse(results.first['postedTime'])
        end_time = time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)  + sprintf('%02i', time.sec)

        p time

        #Get end_time of this response payload.
        time = Time.parse(results.last['postedTime'])
        start_time = time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)  + sprintf('%02i', time.sec)

        p time

        rule_str = rule.gsub(/[^[:alnum:]]/, "")[0..9]
        filename = "#{rule_str}_#{start_time}_#{end_time}"
        return filename
    end

    def append_rules(response, this_rule, tag)

        #Build the "matching_rules" hash that will be added to payload hash.
        matching_rules = []
        rule = {}
        rule["value"] = this_rule
        rule["tag"] = tag
        matching_rules << rule

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

        request = build_request(rule, from_date, to_date)

        if !interval.nil?
            request[:bucket] = interval
        else
            request[:bucket] = @interval
        end

        return JSON.generate(request)
    end

    def build_data_request(rule, from_date=nil, to_date=nil, max_results=nil, next_token=nil)

        request = build_request(rule, from_date, to_date)

        if !max_results.nil?
            request[:maxResults] = max_results
        else
            request[:maxResults] = @max_results #This client
        end

        if !next_token.nil?
            request[:next] = next_token
        end

        return JSON.generate(request)
    end

    def make_data_request(rule, start_time, end_time, max_results, next_token, tag)

        @http.url = @urlSearch
        data = build_data_request(rule, start_time, end_time, max_results, next_token)

        if (Time.now - @request_timestamp) < 1 then
            sleep 1
        end
        @request_timestamp = Time.now


        p data

        begin
            response = @http.POST(data)
        rescue
            sleep 5
            response = @http.POST(data) #try again
        end

        #Prepare to convert Search API JSON to hash.
        api_response = []
        api_response = JSON.parse(response.body)

        if !(api_response["error"] == nil) then
            p "Handle error!"
        end

        if @write_rules then
            #Add rules/tags metadata.
            api_response = append_rules(api_response, rule, tag)
        end

        if @storage == "files" then #write the file.

            #Each 'page' has a start and end time, go get those for generating filename.

            filename = ""
            filename = get_file_name(rule, api_response['results'])

            p "Storing Search API data in file: #{filename}"

            if @compress_files then
                File.open("#{@out_box}/#{filename}.json.gz", 'w') do |f|
                    gz = Zlib::GzipWriter.new(f, level=nil, strategy=nil)
                    gz.write api_response.to_json
                    gz.close
                end
            else
                File.open("#{@out_box}/#{filename}.json", "w") do |new_file|
                    new_file.write(api_response.to_json)
                end
            end
        elsif @storage == "database" #store in database.
            p "Storing Search API data in database..."

            results = []
            results = api_response['results']

            results.each do |activity|

                #p activity
                @datastore.storeActivity(activity.to_json)
            end
        else
            results = []
            results = api_response['results']
            results.each do |activity|
                puts activity.to_json
            end
        end

        #p api_response['next']

        #Return next_token, or 'nil' if there is not one provided.
        return api_response['next']
    end

    #Make initial request, and look for 'next' token, and re-request until the 'next' token is no longer provided.
    def get_data(rule, start_time, end_time, interval, tag=nil)

        next_token = 'first request'

        time_span = "#{start_time} to #{end_time}.  "
        if start_time.nil? and end_time.nil? then
            time_span = "last 30 days."
        elsif start_time.nil? then
            time_span = "30 days ago to #{end_time}. "
        elsif end_time.nil?
            time_span = "#{start_time} to now.  "
        end

        while !next_token.nil? do
            if next_token == 'first request' then
                next_token = nil
            end
            next_token = make_data_request(rule, start_time, end_time, max_results, next_token, tag)
        end

    end #process_data

end #pt_stream class.