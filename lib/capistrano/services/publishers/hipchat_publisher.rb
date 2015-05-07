require 'hipchat'

module Services
  module Publishers

    class HipChatPublisher

      def initialize(api_token)


        @client = HipChat::Client.new(api_token)



      end

      def publish_release(release_version, system_name, env, room_name, issues = [])


        output = ''
        issues.each{|i| output << "<a href=\"#{i.link}\">#{i.id}</a> - #{i.title}<br/>"  }

        message = "#{system_name} version #{release_version} released to #{env.to_s.upcase}<br/> #{output}"

        @client[room_name].send('cap deploy', message, :message_format => 'html')


      end


    end

  end
end