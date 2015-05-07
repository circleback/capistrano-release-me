# capistrano-release-me
cap plugin to help with release tracking as part of the deployment process

### Integration Steps
* install gem in Gemfile (under :development group)
```ruby
gem capistrano-releaseme , :require => false
```
* in Capfile
```ruby
require 'capistrano-releaseme'
```
* in deploy.rb
```ruby
set :git_working_directory, Dir.pwd
set :publisher_api_token, 'token for hipchat'
set :publisher_chat_room, 'Name of HipChat room'
set :publisher_system_name, 'Name of system you are integrating with'
```
* install via bundler
```ruby
bundle install
```


### cap deploying the build
Once integration is done you can do things like this
```
bundle exec cap qa deploy
```
which will by default create a local git tag (v0.0.1 for example) and push the tag after deployment. If a tag already exists previously, it will scan the git commit log for messages and extract out JIRA formatted issue patterns. If found, it will pull these stories that were committed against and add them to the release notes when the message is posted to HipChat.

To manage the tag version stamping into git you can do `bundle exec cap qa deploy version_increase=major|minor|patch|none`. The default is patch, which will increase the last patch number of the tag (v.0.0.2).  So if version_increase argument is ommitted, it will increase the patch level of the tag. You may also want to mod the production.rb file for your production cap deployment. I added `set :version_increase, 'none'` to make sure that when deploying to production, I dont increase the version number - since I am normally just deploying an existing QA-ed tag....um...right?????


 
