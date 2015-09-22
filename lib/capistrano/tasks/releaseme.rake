require 'capistrano/deploy'
require 'git-version-bump'
require 'git-version-bump/rake-tasks'

namespace :load do
  task :defaults do
    set :issue_tracker, :jira
    set :jira_username, ENV['JIRA_USERNAME']
    set :jira_password, ENV['JIRA_PASSWORD']
    set :jira_site_url, 'https://circleback.atlassian.net'

    set :source_manager, :git
    set :git_working_directory, :working_directory_not_set

    default_version_increase = ENV['version_increase']
    default_version_increase ||= 'patch'
    set :version_increase, default_version_increase

    set :publisher, :hip_chat
    set :publisher_api_token, :publisher_api_token_not_set
    set :publisher_chat_room, :publisher_chat_room_not_set
    set :publisher_system_name, :publisher_system_name_not_set
    set :env_to_deploy, ENV['rack_env']

    set :aws_key, ENV['AWS_ACCESS_KEY_ID']
    set :aws_secret, ENV['AWS_SECRET_ACCESS_KEY']
    set :aws_elb_name, ''

  end
end

namespace :releaseme do
  task :deregister_instance, :instance_id do |t, args|
    instance_id = args[:instance_id]
    deregister_instance(instance_id)
  end

  task :register_instance, :instance_id do |t, args|
    instance_id = args[:instance_id]
    register_instance(instance_id)
  end

end

namespace :deploy do

  after :cleanup, :releaseme do
    run_locally do

      git_working_directory = fetch(:git_working_directory)
      version_increase = fetch(:version_increase)

      old_version = "v#{GVB.major_version(true)}.#{GVB.minor_version(true)}.#{GVB.patch_version(true)}"
      story_ids = []

      unless version_increase == 'none'
        info "current version tag #{old_version}"
        if version_increase == 'major'
          GVB.tag_version "#{GVB.major_version(true) + 1}.0.0"
        elsif version_increase == 'minor'
          GVB.tag_version "#{GVB.major_version(true)}.#{GVB.minor_version(true)+1}.0"
        elsif version_increase == 'patch'
          GVB.tag_version "#{GVB.major_version(true)}.#{GVB.minor_version(true)}.#{GVB.patch_version(true)+1}"
        end

        info "version tag bumped to #{GVB.version(true)}"
      end

      unless git_working_directory == :working_directory_not_set
        git_mgr = Services::SourceManagers::GitManager.new(git_working_directory)
        new_version = "v#{GVB.major_version(true)}.#{GVB.minor_version(true)}.#{GVB.patch_version(true)}"

        if git_mgr.tag_exists(old_version)
          unless new_version == old_version
            info "getting commits between #{old_version} and #{new_version}"
            commits = git_mgr.get_commits(old_version, new_version) unless version_increase == 'none'
            story_ids = git_mgr.get_story_ids(commits)
            info "story ids found for this release #{story_ids.length} stories"
          end
        end

      end

      jira_site_url = fetch(:jira_site_url)
      jira_username = fetch(:jira_username)
      jira_passwword = fetch(:jira_password)

      tracker = Services::IssueTrackers::JiraTracker.new(jira_site_url, jira_username, jira_passwword)

      issues = tracker.get_issues(story_ids)
      output = ''
      issues.each{|i| output << "#{i.id} - #{i.title}\n"  }

      if issues.length > 0
        info " #{issues.length} issues loaded from JIRA"
        info "**** RELEASE NOTES FOR #{new_version}*****"
        info output
        info "****** END RELEASE NOTES *********"

      end

      publisher_api_token = fetch(:publisher_api_token)
      unless publisher_api_token == :publisher_api_token_not_set

        pub = Services::Publishers::HipChatPublisher.new(publisher_api_token)
        env_to_deploy = fetch(:env_to_deploy)

        pub.publish_release(new_version, fetch(:publisher_system_name),env_to_deploy,fetch(:publisher_chat_room),issues)

      end


    end
  end


end

def get_loadbalancer_name(env)
  lb_name = fetch(:aws_elb_name)

  lb_name

end

def get_aws_elb
  aws_key = fetch(:aws_key, nil)
  aws_secret = fetch(:aws_secret, nil)

  if aws_key && aws_secret
    elb = AWS::ELB.new(:aws_access_key_id => aws_key,
                       :aws_secret_access_key => aws_secret)
  else
    :no_aws_configuration
  end


end

def deregister_instance(instance_id)

  elb = get_aws_elb
  unless elb == :no_aws_configuration
    lb_name = get_loadbalancer_name(fetch(:rack_env))
    unless lb_name.empty?

      puts "about to deregister instance #{instance_id} from load balancer #{lb_name}"

      aws_response = elb.client.describe_load_balancers({:load_balancer_names => [lb_name]})

      instances_list = aws_response[:load_balancer_descriptions][0][:instances]
      dereg_response = elb.client.deregister_instances_from_load_balancer({:load_balancer_name => lb_name, :instances => [{:instance_id => instance_id}]})

      max_tries = 15
      is_completed = false
      10.times do |i|
        puts "requery attempt #{i}"
        begin
          aws_response = elb.client.describe_instance_health({:load_balancer_name => lb_name, :instances => [{:instance_id => instance_id}] })
        rescue AWS::ELB::Errors::InvalidInstance => aws_err
          puts "instance #{instance_id} not yet in load balancer, end deregister attempt"
          break
        end
        sleep(3)
        puts "aws_response from requery #{i} #{aws_response.inspect} "

        if !aws_response[:instance_states].nil?
          is_completed = aws_response[:instance_states].any?{|x| x[:state] == "OutOfService" && x[:instance_id] == instance_id }

          break if is_completed || i >= max_tries

        end

      end

      if is_completed
        puts "instance #{instance_id} is removed from load balancer"
      else
        puts "ERROR*** removing instance #{instance_id}"
      end

      is_completed

    end
  end

end

def register_instance(instance_id)

  elb = get_aws_elb
  unless elb == :no_aws_configuration
    lb_name = get_loadbalancer_name(fetch(:rack_env))

    unless lb_name.empty?

      puts "about to register instance #{instance_id} on load balancer #{lb_name}"

      reg_response = elb.client.register_instances_with_load_balancer({:load_balancer_name => lb_name, :instances => [{:instance_id => instance_id}]})

      puts "reg_response #{reg_response.inspect}"

      max_tries = 15
      is_registered = false

      10.times do |i|
        puts "requery attempt #{i}"
        aws_response = elb.client.describe_instance_health({:load_balancer_name => lb_name, :instances => [{:instance_id => instance_id}] })
        sleep(3)
        puts "aws_response from requery #{i} #{aws_response.inspect} "

        if !aws_response[:instance_states].nil?
          is_registered = aws_response[:instance_states].any?{|x| x[:state] == "InService" && x[:instance_id] == instance_id }

          break if is_registered || i >= max_tries

        end
      end


      if is_registered
        puts "instance #{instance_id} is added to load_balancer"
      else
        puts "ERROR*** PROBLEM ADDING instance #{instance_id} to load_balancer"
      end

      is_registered

    end
  end



end

def get_instances

  elb = get_aws_elb
  instances_list = []
  unless elb == :no_aws_configuration
    lb_name = get_loadbalancer_name(fetch(:rack_env))


    puts "#{lb_name} is lb_name"

    unless lb_name.empty?
      aws_response = elb.client.describe_load_balancers({:load_balancer_names => [lb_name]})

      instances_list = aws_response[:load_balancer_descriptions][0][:instances]
    end
  end



  instances_list
end
