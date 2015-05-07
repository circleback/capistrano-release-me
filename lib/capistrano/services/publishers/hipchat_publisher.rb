require 'hipchat'

module Services
  module Publishers

    class HipChatPublisher

      def initialize(api_token)


        @client = HipChat::Client.new(api_token)



      end

      def publish_release(release_version, system_name, env, release_notes, room_name)

        message = "#{system_name} version #{release_version} released to #{env} \n #{release_notes}"

        @client[room_name].send('Release Publisher', message, :message_format => 'text')


      end


    end

  end
end