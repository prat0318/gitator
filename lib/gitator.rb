require "gitator/version"
require "octokit"
require "phrasie"
require "json"
require "pp"
require "logger"

module Gitator
	attr_accessor :client, :username, :repos, :is_client_auth, :lang
	attr_accessor :own_repo, :contri_repo, :forked_repo
	attr_accessor :logger

	class Main
		LANG_COUNT = 3
		REPO_DESCR_COUNT = 6
		FETCH_REPO = 30
		WORDS_LIMIT = 5
		DOUBLE = 2
		SINGLE = 1
		SEARCH_RESULT=10
		SHOW_SUGG = 6
		@@extractor ||= Phrasie::Extractor.new

		def initialize(client, options={})
			@client = client
			@username = client.login || options[:owner]
			@is_client_auth = !!client.login
			@lang = [], @own_repo = [], @contri_repo = [], @forked_repo = []
			@logger = Logger.new(STDOUT)
			@logger.level = Logger::INFO
		end
	
		def set_repos
			username = @username if !@is_client_auth
			@repos = with_logging("fetch repos") do
				@client.repositories(username, {:per_page => FETCH_REPO, :type=> 'all', :sort=>'updated'})
			end
			@repos.each do |repo|
				@own_repo << repo if own_repo? repo
				@forked_repo << repo if forked_repo? repo
				@contri_repo << repo if contri_repo? repo
			end
			# @owned_repo = @repos.select{|repo| repo.owner.login == @username && repo.fork == false}
			assign_lang
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

		def suggest_from(repo, for_lang, since)
			return [] if repo.empty?
			search_string = parse_descriptions repo
			search_string += " language:#{for_lang}" unless for_lang.nil?
			search_string += " pushed:>#{since}"
			result = @client.search_repositories(search_string, {:per_page => SEARCH_RESULT,
																													 :headers => { :accept =>
																													 	'application/vnd.github.v3.text-match+json'
																													 	}})
			result.items.reject{|r| r.owner.login == @username}[0..(SHOW_SUGG-1)]
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

		def get_suggestions
			set_repos if @repos.nil?
			repos = {:own => @own_repo, :contri => @contri_repo, :forked=> @forked_repo}
			result = []
			@lang.each do |lang|
				repos.each do |k,v|
					with_logging("search") do
					  result << [lang, k, v.map(&:name), (suggest_from v, lang, (Date.today << 6))]
					end
				end
			end

			JSON.pretty_generate({
				:lang => @lang,
			  :owner => @username,
			  :suggestions => result.map do |r1|
			  										 {
			  										 	:meta => r1[0..2],
			  										 	:result => r1[3].map do |r|
			  										 	{
				  										 	:name => r.name, 
				  										 	:owner => r.owner.login, 
				  										 	:forks => r.forks,
				  	                    :watchers => r.watchers, 
				  	                    :score => r.score, 
				  	                    :match => r.text_matches.map do |tm|
				  	                              	{
				  	                              		:fragment => tm.fragment, 
				  	                              		# :matches => tm.matches.map(&:text)
				  	                              	}
				  	                              end
				  	                    }
  	                            end
			  	                    }
			  	              end      

			})
		end

		def with_logging(desc)
			start = Time.now
			result = yield
			@logger.info("Time taken for #{desc} : #{Time.now - start} secs.")
			result
		end
	end
end
