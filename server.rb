require 'sinatra/auth/github'
require 'gitator'
require 'octokit'
require 'json'
require 'pp'
require 'uri'

module Gitator
  class App < Sinatra::Base

    CLIENT_ID = ENV['CLIENT_ID']
    CLIENT_SECRET = ENV['CLIENT_SECRET']

    enable :sessions

    set :github_options, {
      :scopes => "",
      :secret => CLIENT_SECRET,
      :client_id => CLIENT_ID,
      :callback_url => "/",
    }

    # set :main, nil

    register Sinatra::Auth::Github

    def get_client(params)
      if(params["public"] == "true") 
        owner = params["username"] || 'prat0318'
        client = Octokit::Client.new(
          :client_id => CLIENT_ID,
          :client_secret => CLIENT_SECRET,
          :auto_paginate => false)
        return Gitator::Main.new client, {:owner => owner}
      else
         if !authenticated?
            authenticate!
         else
          client = Octokit::Client.new(
            :login => github_user.login,
            :access_token => github_user.token,
            :auto_paginate => false
          )
          return Gitator::Main.new client, {}
        end
      end
    end

    get '/' do
      begin
        @main = get_client(params)
      rescue Octokit::NotFound => e
        return erb :not_found, :locals => {:error => "#{owner} not found!"}
      end
      erb :index, :locals => {}
    end

    get '/suggest' do
      @main = get_client(params)
      param = Hash[params.map{ |k, v| [k.to_sym, v] }]
      begin
        @main.send("get_#{param[:search_type]}_suggestions", param)
      rescue Exception => e
        [500, {'Content-Type' => 'application/json'}, [{:type => e.class.to_s}.to_json]]
      end
    end

    get '/profile_info' do
      @main = get_client(params)
      @main.send("get_profile_info", params["id"])
    end

    # get '/' do

    #   if !authenticated?
    #     authenticate!
    #   else
    #     client = Octokit::Client.new(
    #       :login => github_user.login,
    #       :access_token => github_user.token,
    #       :auto_paginate => false
    #     )
    #     settings.main = Gitator::Main.new client, {}
    #     erb :index, :locals => {}
    #   end
    # end
  end
end