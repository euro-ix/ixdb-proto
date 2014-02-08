require 'sinatra'
require 'erb'
require 'mysql'
require 'json'

def full_result_hashback(select_command)
	puts select_command
	# Return an array of hashes from a MySQL query result, one row per array unit, each row as a hash.
	result_list_of_hashes=[]
	begin
		db_con = Mysql.new 'localhost', 'euroixapi-select', 'eixbrowse', 'euroix_production'
		list_results     = db_con.query(select_command)
		while row = list_results.fetch_hash do
			result_list_of_hashes.push(row)
		end
	rescue Mysql::Error => e
		puts e.errno
		puts e.error
	ensure
		db_con.close if db_con
	end
	return result_list_of_hashes
end

# Start webserver.  Run web app on all IPs.
set :bind, '0.0.0.0'

# Make an array of a list of countries for the search tool
country_code_list = Array.new
country_code_hash = full_result_hashback("SELECT country_code FROM countries")
country_code_hash.each do |row|
	country_code_list.push(row["country_code"])
end

get '/list/:output_format/:verbosity/:country/:active/' do
	select_command='SELECT '
	# List of rows to select depends on verbosity indicated

	#fixme - get the column names as keys in the hash, it's pretty fucking ugly this way
	#        html view expects the column names to match the sql column names.  just sayin'.
	case params[:verbosity]
	when "terse"
		select_command = select_command + "i.id, i.short_name FROM ixps i, countries c WHERE c.id=i.country_id "
		@column_names = ['id', 'short_name']
	when "brief"
		select_command = select_command + "i.id, i.full_name, i.city, i.state, c.country_code, c.name as country_name FROM ixps i, countries c WHERE c.id=i.country_id "
		@column_names = ['id','full_name','city','state','country_code','country_name']
	else
		halt 404
	end

	if country_code_list.include? params[:country]
		select_command = select_command + "AND c.country_code='" + params[:country] +"' "
	elsif params[:country] == "all"
		# Do nothing.
	else
		puts "Invalid country code: " + params[:country]
		halt 404
	end

	case params[:active]
	when "active"
		select_command = select_command + "AND state='active' "
	when "inactive"
		select_command = select_command + "AND state='inactive' "
	else
		# "All" is the equivilent
	end

	@list_of_ixps = full_result_hashback(select_command)

	case params[:output_format]
	when "ruby"
		@display = @list_of_ixps
		erb :blank, layout: false
	when "json"
		@display = @list_of_ixps.to_json
		erb :blank, layout: false
	when "html"
		erb :list_ixp
	end
end

error 404 do
	puts "No such URL"
end
