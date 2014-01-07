# Gitator

Repo/user recommendation engine on basis of user's GitHub profile.

## Running it on the local machine

    $ #git clone the directory in your favorite folder
    
    $ cd gitator

    $ bundle
    
    $ CLIENT_ID=asdf CLIENT_SECRET=qwert bundle exec rackup -p9393

If every thing goes fine, localhost:9393 will now be hosting gitator locally on your machine.

## Future Additions

Currently, it is in a very naive phase, and there is a scope of huge improvement. A few ideas which come across my mind are:

1. Using the 'following' data (people who the user follows) to understand user's taste and give suggestions on basis of that.
2. Reducing the number of API calls (using something like Redis and GitHub conditional API requests).
3. Using much more smarter keyword extraction tool from the phrase built from user's profile.

I would be more than happy to know any kind of suggestions which could improve the model further.

## Contributing

As I said, there is a lot of scope of improvement, both from an angle of design as well as implementation.

Any kind of contribution (through a pull-request), small or big, is whole heartedly welcome.

##Credits

1. Thanks to [mdo/github-buttons](https://github.com/mdo/github-buttons) from which github buttons CSS is copied. (I would directly use the iframe but would incur an API call)
2. Thanks to [ashleyw/phrasie](https://github.com/ashleyw/phrasie/) which i have used as a gem for keyword extraction from a phrase.
3. Finally, to [octokit/octokit.rb](https://github.com/octokit/octokit.rb) which is written so cleanly and beautifully.
