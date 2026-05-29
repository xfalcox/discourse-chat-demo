# frozen_string_literal: true

module ::ChatDemo
  # Prepares the target chat channel (chosen via chat_demo_channel_id, defaulting
  # to the shipped "General" channel, id 2) and joins the cast. It does NOT
  # create a channel — it posts into an existing one, to avoid ending up with a
  # second "general"-style channel alongside the one Discourse already ships.
  module ChannelSetup
    RETENTION_DAYS = 2

    def self.ensure!
      channel = target_channel
      if channel.nil?
        Rails.logger.warn(
          "discourse-chat-demo: chat_demo_channel_id=#{SiteSetting.chat_demo_channel_id} is not a chat channel; nothing to prepare"
        )
        return nil
      end

      enable_chat!
      prepare_channel(channel)
      join_cast(channel)
      channel
    end

    def self.target_channel
      id = SiteSetting.chat_demo_channel_id.to_i
      return nil if id <= 0

      Chat::Channel.find_by(id: id)
    end

    def self.enable_chat!
      SiteSetting.chat_enabled = true unless SiteSetting.chat_enabled
      SiteSetting.enable_public_channels =
        true unless SiteSetting.enable_public_channels
      # Demo content is high-volume and ephemeral; keep only a couple of days.
      SiteSetting.chat_channel_retention_days = RETENTION_DAYS
    end

    def self.prepare_channel(channel)
      # Put the AI-content disclaimer where it stays visible, and stop the
      # generated script from ever @here/@all-pinging real members.
      channel.update!(
        description: I18n.t("chat_demo.disclaimer"),
        allow_channel_wide_mentions: false
      )
    end

    def self.join_cast(channel)
      Cast.users.find_each do |user|
        channel
          .user_chat_channel_memberships
          .find_or_create_by!(user: user) do |membership|
            membership.following = true
          end
      end
    end
  end
end
