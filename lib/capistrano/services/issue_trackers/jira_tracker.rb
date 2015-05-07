require 'jira'


module Services
  module IssueTrackers

    class JiraTracker

      def initialize(jira_api_url, jira_user, jira_password)

        username = jira_user
        password = jira_password

        options  = {:username => username, :password => password, :site => jira_api_url, :context_path => '', :auth_type => :basic}

        @client = JIRA::Client.new(options)

      end

      def get_issues(issue_ids)

        issues = []

        # JQL => id in ('SIQ-531','SIQ-556')
        jql_string = 'id in (' + issue_ids.map{|id| "'#{id}'" }.join(",") + ')'

        begin

          @client.Issue.jql(jql_string).each do |issue|
            i = Services::IssueTrackers::Issue.new
            i.title = issue.fields['summary']
            i.id = issue.key
            i.link =  "#{@client.options[:site]}/browse/#{issue.key}"
            i.status = issue.status.name

            issues << i
          end

        rescue JIRA::HTTPError => error

        end

        issues

      end

    end

    class Issue
      attr_accessor :title
      attr_accessor :id
      attr_accessor :link
      attr_accessor :status
    end

  end
end