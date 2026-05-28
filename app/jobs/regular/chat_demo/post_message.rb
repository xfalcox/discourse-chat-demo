# frozen_string_literal: true

module ::Jobs
  module ChatDemo
    # Posts exactly one scripted line, claimed atomically so concurrent fan-out
    # jobs never post the same line twice.
    class PostMessage < ::Jobs::Base
      def execute(_args)
        return unless SiteSetting.chat_demo_enabled

        channel_id = SiteSetting.chat_demo_channel_id.to_i
        return if channel_id <= 0

        line = ::ChatDemo::Message.claim_next!
        return if line.nil?

        user = User.find_by(username_lower: line.username.downcase)
        return if user.nil?

        ::Chat::CreateMessage.call(
          guardian: user.guardian,
          params: {
            chat_channel_id: channel_id,
            message: line.message
          },
          options: {
            enforce_membership: true,
            process_inline: true
          }
        )
      end
    end
  end
end
