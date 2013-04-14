#!/usr/bin/env ruby
DEFAULT_ARCHIVE_APIKEY = "YOUR_ARCHIVE_VG_APIKEY"
DEFAULT_OEDB_FILEPATH = "#{Dir.home}/Library/Application Support/OpenEmu/Game Library/Library.storedata"

require 'sqlite3'
require 'net/http'
require 'json'
require 'optparse'

begin
  # setting default parameters
  apikey = DEFAULT_ARCHIVE_APIKEY
  oedb_filepath = DEFAULT_OEDB_FILEPATH

  # Command line options
  opt_parser = OptionParser.new do |opt|
    opt.banner = "Usage: ./openemu-archivevg-matcher.rb [OPTIONS]"
    opt.separator  ""
    opt.separator  "Options"

    opt.on("-a","--apikey YOUR_ARCHIVE_VG_APIKEY","Your Archive.vg API key") do |option_apikey|
      apikey = option_apikey
    end

    opt.on("-db","--database FILEPATH","path to your OpenEmu library database") do |option_oedb_filepath|
      oedb_filepath = option_oedb_filepath
    end

    opt.on("-h","--help","help") do
      puts opt_parser
      exit
    end
  end
  opt_parser.parse!

  # some sanity checking: filepath 
  abort "OpenEmu database file not found!" unless File.exist? oedb_filepath
  # some sanity checking: API key
  url = "http://api.archive.vg/2.0/Archive.getSystems/json/#{apikey}/"
  http_code = Net::HTTP.get_response(URI.parse(url)).code
  abort "Connecting to the Archive.vg API failed... check your API key!" if http_code.to_i != 200

  # Everything seems to be fine, let's go!
  # general database stuff
  oedb = SQLite3::Database.open oedb_filepath
  oedb.results_as_hash = true

  # get all entries that have not been matched to archive.vg yet
  rows = oedb.execute "select Z_PK, ZNAME from ZGAME where ZARCHIVEID = 0;" 
  
  # iterate over all entries
  rows.each do  |row|
    game_key = row['Z_PK']
    game_name = row['ZNAME']
    puts "Checking #{game_name}..."
     # kill all special characters in game name except space, makes search easier
    game_name_clean = game_name.gsub(/[^0-9A-Za-z ]/, '')
    
    ### BEGIN FUZZY SEARCH: search for the whole title and if no results come up, remove word by word
    wordnum = game_name_clean.split.size
    resultsnum = 0

    until wordnum == 0 || resultsnum > 0
      search_term = ""
      wordnum.times do |i|
        search_term += game_name_clean.split[i]
        search_term += "+" 
      end

      # execute the search and keep fingers crossed for resultsnum > 0
      url = "http://api.archive.vg/2.0/Archive.search/json/#{apikey}/#{search_term}"
      response = Net::HTTP.get_response(URI.parse(url)).body
      json_data = JSON.parse(response) ['games']['game']

      # somewhat weird resultnum decider... 
      # json response from archive.vg is only an array for >= 2 results
      # I don't know how to make it more elegant
      if json_data.nil?
        resultsnum = 0 
      elsif json_data.kind_of?(Array)
        resultsnum = json_data.length 
      else
        resultsnum = 1
      end

      # no results? remove one word and try again 
      wordnum = wordnum - 1  if resultsnum == 0
    end
    ### END FUZZY SEARCH

    unless wordnum == 0   # no results found, even after reducing the search terms - give up, next game
      # only one result, we assume a match. No interaction needed.
      if resultsnum == 1 
        archive_id = json_data['id'].to_i
        archive_title = json_data['title']
      # more than one result, let user decide.
      elsif resultsnum > 1
        puts "Multiple matches found for \"#{game_name}\" - please select:"
        puts "[0] - NONE OF THE FOLLOWING"
        json_data.each_with_index do |gamedata, i|
          print "[#{i+1}] - "
          print gamedata['title']
          print " ("
          print gamedata['system_title']
          puts ")"
        end
        print "Selection -> "
        STDOUT.flush  
        selection = gets.chomp  
        archive_id = selection.to_i > 0 ? json_data[(selection.to_i)-1]['id'].to_i : 0
        archive_title = json_data[(selection.to_i)-1]['title']
      end
 
      # update database entry with ID of chosen game
      puts "Matched: #{archive_title}" if archive_id > 0
      oedb.execute "update ZGAME set ZARCHIVEID = #{archive_id} where Z_PK = #{game_key}" if archive_id > 0
    end
  end 

end