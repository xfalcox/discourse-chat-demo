# frozen_string_literal: true

module ::ChatDemo
  # Creates (once) the category + chat channel that receives generated messages
  # and joins the cast. The AI-content disclaimer lives in the channel
  # description so it stays visible (a posted message would scroll away).
  module ChannelSetup
    RETENTION_DAYS = 2

    def self.ensure!
      existing = current_channel
      return existing if existing

      enable_chat!

      category = ensure_category
      channel = find_or_create_channel(category)

      SiteSetting.chat_demo_category_id = category.id
      SiteSetting.chat_demo_channel_id = channel.id

      join_cast(channel)

      channel
    end

    def self.current_channel
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

    def self.ensure_category
      id = SiteSetting.chat_demo_category_id.to_i
      category = Category.find_by(id: id) if id > 0
      category ||
        Category.create!(
          name: I18n.t("chat_demo.category_name"),
          user: Discourse.system_user
        )
    end

    def self.find_or_create_channel(category)
      # Generic channel name (not the game name) — a game's Discord has a
      # "#general", not a room named after the game.
      name = I18n.t("chat_demo.channel_name")

      existing = Chat::Channel.find_by(chatable: category, name: name)
      return existing if existing

      result =
        Chat::CreateCategoryChannel.call(
          guardian: Discourse.system_user.guardian,
          params: {
            name: name,
            description: I18n.t("chat_demo.disclaimer"),
            category_id: category.id,
            auto_join_users: false
          }
        )

      if result.failure?
        raise "discourse-chat-demo: failed to create channel (#{result.inspect})"
      end

      # Prevent the generated script from ever @here/@all-pinging real members.
      result.channel.update!(allow_channel_wide_mentions: false)
      result.channel
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
