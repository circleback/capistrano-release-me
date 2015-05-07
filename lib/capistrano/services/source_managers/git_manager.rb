require 'git'
require 'logger'

module Services
  module SourceManagers

    class GitManager

      def initialize(working_path)

        if Dir.exists?(working_path)
          @git = Git.open(working_path, :log => Logger.new(STDOUT))
        else
          raise ArgumentError.new("working_path '#{working_path}' not found")
        end

      end

      def get_commits(prev_tag, current_tag)

        git_commits = @git.log.between(prev_tag, current_tag)

        mapped_commits = git_commits.map do |gc|

          c = Commit.new
          c.author = gc.author
          c.message = gc.message
          c.name = gc.name
          c.committed_on = gc.date

          c

        end

        mapped_commits

      end

      def tag_exists(tag_name)
        exists = false
        begin
          @git.tag(tag_name)
            exists = true
        rescue Git::GitTagNameDoesNotExist => tag_error

        end

        exists

      end

      def get_story_ids(commits, story_id_regex_pattern = '^\[?([A-Z]{2,8}-\d{1,11})')

        ids = []
        re = Regexp.new(story_id_regex_pattern)

        commits.each do |commit|
          re.match(commit.message) do |m|
            ids << m[1] if m.length > 0
          end
        end

        ids.uniq

      end


    end

    class Commit
      attr_accessor :message
      attr_accessor :name
      attr_accessor :parent
      attr_accessor :author
      attr_accessor :committed_on
    end


  end
end