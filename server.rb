require 'sinatra/auth/github'
require 'gitator'
require 'octokit'
require 'json'
require 'pp'
require 'uri'
require "logger"

module Gitator
  class App < Sinatra::Base

    CLIENT_ID = ENV['CLIENT_ID']
    CLIENT_SECRET = ENV['CLIENT_SECRET']

    enable :sessions

    set :github_options, {
      :scopes => "",
      :secret => CLIENT_SECRET,
      :client_id => CLIENT_ID,
      :callback_url => "/login?",
    }

    register Sinatra::Auth::Github

    def get_client(params, init = false)
      if(params["public"] == "true") 
        owner = params["username"]
        owner = 'prat0318' if owner.nil? || owner == ""
        client = Octokit::Client.new(
          :client_id => CLIENT_ID,
          :client_secret => CLIENT_SECRET,
          :auto_paginate => false)
        return Gitator::Main.new client, {:owner => owner, :init => init}
      else
         if !authenticated?
            authenticate!
         else
          client = Octokit::Client.new(
            :login => github_user.login,
            :access_token => github_user.token,
            :auto_paginate => false
          )
          return Gitator::Main.new client, {:init => init}
        end
      end
    end

    get '/login' do
      begin
        @main = get_client(params, true)
      rescue Octokit::NotFound => e
        log_error e
        return erb :not_found, :locals => {}
      rescue Exception => e
        log_error e
        return erb :error
      end
      erb :login, :locals => {}
    end

    get '/' do
      erb :index
    end

    get '/suggest' do
      @main = get_client(params)
      param = Hash[params.map{ |k, v| [k.to_sym, v] }]
      begin
        @main.send("get_#{param[:search_type]}_suggestions", param)
      rescue Exception => e
        log_error e
        [500, {'Content-Type' => 'application/json'}, [{:type => e.class.to_s}.to_json]]
      end
    end

    get '/profile_info' do
      @main = get_client(params)
      @main.send("get_profile_info", params["id"])
    end

    def log_error(e)
        @logger = Logger.new(STDOUT)
        @logger.error(e.inspect+"\n\t"+e.backtrace[0..10].join("\n\t"))
    end
  end
end