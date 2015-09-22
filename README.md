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

### Issuing a rolling deployment with AWS ELB
If you have your servers in EC2, and they are  behind a Elastic Load Balancer, then releaseme has the ability to do a basic "rolling deployment". It provides tasks to deregister and register an instance out of the ELB.

To configure rolling deployment you can set additional config in your environment specific files (deploy/production.rb)
```ruby
set :aws_elb_name, 'name_of_aws_elastic_load_balancer'
```
You also need to set the AWS EC2 instance-id for each instance defined in your server area in this environment specific file (again deploy/production.rb)
```ruby
server 'host_name.of.your.box', user: 'some_user', instance_id: 'aws-instance-id' #usually something like i-e80f5400
server 'host_name.of.another.box', user: 'some_user', instance_id: 'aws-instance-id2'
# add more servers that are behind this elb...
```
You also need to pass your AWS EC2 API credentials. All AWS EC2 calls require aws_access_key_id, and aws_secret_access_key to connect.
By default the releaseme gem will look for these values in ENV variables named AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY. If these
env variables are setup on the machine it should work. You could of course set these explicitly in the deploy.rb file
```ruby
set :aws_key, 'mykey'
set :aws_secret, 'mysecret'
```
But if this is in anywhere public - I would not recommend that :)

Once these configurations are set you can call this in your deploy.rb file to unregister the instance
```ruby
# inside a task block in your deploy.rb for example like this
namespace :deploy do
  task :started do |task|
    on roles(:all), in: :sequence, wait: 5 do |host|
      props = host.properties
      current_instance_id = props.fetch(:instance_id) #this pulls from the instance_id: thing we added to the server def in the environment specific file earlier
      puts "removing instance #{current_instance_id}"
      invoke 'releaseme:deregister_instance', current_instance_id
    end
  end
end
# to add back in rotation
namespace :deploy do
  task :finishing do |task|
    on roles(:all), in: :sequence, wait: 5 do |host|
      props = host.properties
      current_instance_id = props.fetch(:instance_id) #this pulls from the instance_id: thing we added to the server def in the environment specific file earlier
      puts "adding instance #{current_instance_id}"
      invoke 'releaseme:register_instance', current_instance_id
    end
  end
end

```


 
