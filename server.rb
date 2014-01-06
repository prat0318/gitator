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
        return log_error_and_render e, :not_found
      rescue Exception => e
        return log_error_and_render e, :error
      end
      erb :login
    end

    get '/' do
      erb :index
    end

    get '/suggest' do
      param = Hash[params.map{ |k, v| [k.to_sym, v] }]
      method_name = "get_#{param[:search_type]}_suggestions"
      call_backend method_name, param
    end

    get '/profile_info' do
      method_name = "get_profile_info"
      call_backend method_name, params["id"]
    end

    def call_backend method_name, args
      @main = get_client(params)
      begin
        @main.send(method_name, args)
      rescue Exception => e
        return log_error_and_render_json e
      end
    end

    def log_error_and_render(e, page)
      log_error e
      erb page
    end

    def log_error_and_render_json e
      log_error e
      [500, {'Content-Type' => 'application/json'}, [{:type => e.class.to_s}.to_json]]
    end

    def log_error(e)
        @logger = Logger.new('logs/gitator.log', 10, 1024000)
        @logger.error(e.inspect+"\n\t"+e.backtrace[0..10].join("\n\t"))
    end
  end
end