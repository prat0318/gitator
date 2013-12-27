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

    register Sinatra::Auth::Github

    get '/public' do
    	owner = params["username"] || 'prat0318'
    	client = Octokit::Client.new(
    		:client_id => CLIENT_ID,
    		:client_secret => CLIENT_SECRET,
    		:auto_paginate => false)
      @main = Gitator::Main.new client, {:owner => owner}
      @output = JSON.parse(@main.get_suggestions(params["lang"], params["repo"]))
      erb :index, :locals => {}
    end

    get '/suggest' do
      
    end

    get '/' do

      if !authenticated?
        authenticate!
      else
        client = Octokit::Client.new(
          :login => github_user.login,
          :access_token => github_user.token,
          :auto_paginate => false
        )
        @main = Gitator::Main.new client, {}
        output = JSON.parse(@main.get_suggestions(params["lang"], params["repo"]))
        erb :index, :locals => {:output => output}
      end
    end
  end
end