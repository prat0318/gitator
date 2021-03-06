require "gitator/version"
require 'pretty_date'
require "octokit"
require "phrasie"
require "json"
require "pp"
require "logger"

module Gitator

	class Main
		attr_accessor :sidebar, :lang, :username, :client, :user_info, :logger

		LANG_COUNT = 4
		REPO_DESCR_COUNT = 6
		MONTHS_AGO = 6
		FETCH_REPO = 30
		WORDS_LIMIT = 5
		DOUBLE = 2
		SINGLE = 1
		SEARCH_RESULT=10
		SHOW_SUGG = 6
		ALL_LANGS = %w{JavaScript Ruby Java PHP Python C++ C Objective-C C# Shell CSS
    	      Perl CoffeeScript VimL Scala Go Prolog Clojure Haskell Lua}.sort
		@@extractor = Phrasie::Extractor.new({:filter => {:strength=>1, :occur=>1}, :strength=>1, :occur=>1})
		@@org_members = {};

		def initialize(client, options={})
			@client = client
			@username = client.login || options[:owner]
			@is_client_auth = !!client.login
			@lang = []; @sidebar = {}; @following = [@username]
			init_logger

			@query_username = @username if !@is_client_auth #pass nil if user is logged in
			if options[:init]
				@user_info = with_logging("info: #{@query_username}") { client.user @query_username }
				set_repos
				set_orgs
				set_locn
			end
		end
	
	    def init_logger
		  @logger = Logger.new('logs/gitator.log', 10, 1024000)
		  @logger.level = Logger::INFO
		end
		
		def set_repos
			@repos = with_logging("fetch repos") do
				@client.repositories(@query_username, {:per_page => FETCH_REPO, :type=> 'all', :sort=>'updated'})
			end
			@repos_hash = {:own => [], :contri => [], :forked => []}
			@repos.each do |repo|
				@repos_hash[:own] << repo if own_repo? repo
				@repos_hash[:forked] << repo if forked_repo? repo
				@repos_hash[:contri] << repo if contri_repo? repo
			end
			populate_repos_to_sidebar
			assign_lang
		end

		def populate_repos_to_sidebar
			repo_sidebar = []
			repo_sidebar << ['own','Repos you own and aren\'t forked'] unless @repos_hash[:own].empty?
			repo_sidebar << ['forked','Repos you have forked'] unless @repos_hash[:forked].empty?
			repo_sidebar << ['contri','Repos you have contributed to'] unless @repos_hash[:contri].empty?
			@sidebar[:repos] = repo_sidebar
		end

		def set_orgs
			@sidebar[:orgs] = with_logging("get orgs") { client.organizations(@query_username).map(&:login).map{|o| [o,'']} }
		end

		def set_locn
			@sidebar[:locn] =  [[@user_info.location,'']] unless @user_info.location.to_s.empty?
		end

		def own_repo?(repo)
			repo.owner.login == @username && repo.fork == false
		end

		def forked_repo?(repo)
			repo.owner.login == @username && repo.fork == true
		end

		def contri_repo?(repo)
			!own_repo?(repo) && !forked_repo?(repo)
		end

		def call_api_to_suggest_repos(repos, for_lang, since)
			return [] if repos.empty?
			search_string = parse_descriptions repos
			search_string += " language:#{for_lang}" unless for_lang.nil?
			search_string += " pushed:>#{since}"
			result = @client.search_repositories(search_string, {:per_page => SEARCH_RESULT,
																 :headers => { :accept =>
																 	'application/vnd.github.v3.text-match+json'
																 	}})
			result.items.reject{|r| @repos.map(&:name).include? r.name}[0..(SHOW_SUGG-1)]
		end

		def call_api_to_suggest_users(for_lang, options)
			search_string = ""
			search_string += " language:#{for_lang} " unless for_lang.nil?
			search_string += " location:#{options[:locn]} " unless options[:locn].nil?
			unless options[:org_members].nil?
				search_string += options[:org_members].map{|name| "user:#{name}"}.join(" ") 
			end
			#@logger.info("String to be searched : #{search_string}")
			result = @client.search_users(search_string, {:per_page => SEARCH_RESULT})
			result.items.reject{|r| @following.include? r.login}[0..(SHOW_SUGG-1)]
		end

		def parse_descriptions(repos)
			phrase = repos.sort_by{|r| r.updated_at}.reverse[0..(REPO_DESCR_COUNT-1)].
										 map{|r| r.description}.join(" ")
     		words = @@extractor.phrases(phrase).select{|i| i[2] == 1}[0..(WORDS_LIMIT-1)].
      																	 map{|j| j[0]}
			return words.join(" OR ")
		end

		def assign_lang
			grp_size = lambda do |grp| 
				grp.inject(0) { |count, repo| count += (own_repo?(repo) ? DOUBLE : SINGLE) }
			end
			lang = Hash[@repos.group_by{|repo| repo.language}.map{|grp_id, item| [grp_id, grp_size.call(item)]}]			
			@lang = lang.tap{|h| h.delete(nil)}.sort_by{|k,v| v}.reverse.map{|i| i[0]}[0..(LANG_COUNT-1)]
		end

		def options_validated?(options, search_type)
			!(options[:lang].nil? || options[:category].nil? || options[:search_type] != search_type)
		end

		def get_locn_suggestions(options={})
			return {:suggestions => []}.to_json unless options_validated?(options, 'locn')
			locn = options[:category].split(",").first  #Remove state info from location
			lang = options[:lang]
			result = with_logging("search_user_locn") do
			  call_api_to_suggest_users lang, {:locn => locn}
			end			
			{
				:type => 'User',
			  :suggestions => format_user_result(result)      
			}.to_json			
		end

		def get_org_members(org)
			@@org_members[org.to_sym] ||= with_logging("org_members"){ @client.org_members(org).map(&:login) }
		end

		def get_orgs_suggestions(options={})
			return {:suggestions => []}.to_json unless options_validated?(options, 'orgs')
			org = options[:category]
			lang = options[:lang]
			org_members = get_org_members(org)
			result = with_logging("search_user_org") do
			  call_api_to_suggest_users lang, {:org_members => org_members}
			end			

			{
			  :type => 'User',
			  :suggestions => format_user_result(result)      
			}.to_json			
		end

		def get_repos_suggestions(options = {})
			return {:suggestions => []}.to_json unless options_validated?(options, 'repos')
			set_repos unless @repos_hash
			param_lang = options[:lang]
			repo_type = options[:category]
			result = with_logging("search_repo") do
			  call_api_to_suggest_repos @repos_hash[repo_type.to_sym], param_lang, (Date.today << MONTHS_AGO)
			end
			{
			  :type => 'Repo',
			  :suggestions => format_repo_result(result)      
			}.to_json
		end

		def get_profile_info(id)
			with_logging("fetch profile info #{id}") do 
				attrs = @client.user(id).attrs
				attrs.merge(:last_activity => attrs[:updated_at].to_pretty).to_json
			end
		end

		def format_user_result(result)
			result.map do |r|
				{
					:login => r.login,
					:type => r.type,
					:gravatar_id => r.gravatar_id,
				}
			end
		end

		def format_repo_result(result)
			result.map do |r|
			 {
			 	:name => r.name, 
			 	:owner => r.owner.login, 
			 	:forks => r.forks,
		        :watchers => r.watchers, 
		        :description => r.description,
		        :score => r.score, 
		        :last_activty => r.updated_at.to_pretty,
		        :match => r.text_matches.map do |tm|
		                  	{
		                  		:fragment => tm.fragment, 
		                  		:matches => tm.matches.map(&:text)
		                  	}
		                  end
	        }
	      end
	    end


		def with_logging(desc)
			start = Time.now
			result = yield
			@logger.info("Time taken for #{desc} : #{Time.now - start} secs.")
			result
		end

		# def method_missing
		# 	raise new Exception("Method not defined!")
		# end

	end
end
