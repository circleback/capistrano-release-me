require 'capistrano/deploy'
require 'git-version-bump'

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

  end
end

namespace :deploy do

  after :cleanup, :releaseme do
    run_locally do

      git_working_directory = fetch(:git_working_directory)
      version_increase = fetch(:version_increase)

      old_version = GVB.version
      story_ids = []

      unless version_increase == 'none'
        puts "current version tag #{old_version}"
        execute :rake, "version:bump:#{version_increase}"
        puts "version tag bumped to #{GVB.version}"
      end

      unless git_working_directory == :working_directory_not_set
        git_mgr = Services::SourceManagers::GitManager.new(git_working_directory)
        new_version = GVB.version
        puts "getting commits between #{old_version} and #{new_version}"
        commits = git_mgr.get_commits(old_version, new_version)
        story_ids = git_mgr.get_story_ids(commits)
        puts "story ids found for this release #{story_ids.length} stories"
      end

      jira_site_url = fetch(:jira_site_url)
      jira_username = fetch(:jira_username)
      jira_passwword = fetch(:jira_password)

      tracker = Services::IssueTrackers::JiraTracker.new(jira_site_url, jira_username, jira_passwword)

      issues = tracker.get_issues(story_ids)
      output = ''
      issues.each{|i| output << i.title + "\n"  }

      puts " #{issues.length} issues loaded from JIRA"

      File.write('/Users/jaydanielian/code/dub/siq/temp_file.txt', output)


    end
  end


end