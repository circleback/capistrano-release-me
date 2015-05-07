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

        begin
          git_mgr.tag(old_version)
          unless new_version == old_version
            info "getting commits between #{old_version} and #{new_version}"
            commits = git_mgr.get_commits(old_version, new_version)
            story_ids = git_mgr.get_story_ids(commits)
            info "story ids found for this release #{story_ids.length} stories"
          end
        rescue
          info "old tag is not found"
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