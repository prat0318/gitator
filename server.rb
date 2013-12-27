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

    set :main, nil

    register Sinatra::Auth::Github

    get '/public' do
    	owner = params["username"] || 'prat0318'
    	client = Octokit::Client.new(
    		:client_id => CLIENT_ID,
    		:client_secret => CLIENT_SECRET,
    		:auto_paginate => false)
      settings.main = Gitator::Main.new client, {:owner => owner}
      erb :index, :locals => {}
    end

    get '/suggest' do
      settings.main.get_suggestions(params["lang"], params["repo"])
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
        settings.main = Gitator::Main.new client, {}
        erb :index, :locals => {}
      end
    end
  end
end