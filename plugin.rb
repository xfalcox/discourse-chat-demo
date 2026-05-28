# frozen_string_literal: true

# name: discourse-chat-demo
# about: Seeds a Discourse Chat channel with AI-generated, continuously refreshed mock conversations, for demo sites.
# version: 0.1
# authors: Discourse
# url: https://github.com/discourse/discourse-chat-demo

enabled_site_setting :chat_demo_enabled

module ::ChatDemo
  PLUGIN_NAME = "discourse-chat-demo"
end

require_relative "lib/chat_demo/engine"

after_initialize do
  register_user_custom_field_type(::ChatDemo::Cast::CUSTOM_FIELD, :boolean)

  # When the plugin is switched on, set up the cast + channel and kick off an
  # immediate script generation rather than waiting for the daily scheduled run.
  on(:site_setting_changed) do |name, _old_value, new_value|
    if name == :chat_demo_enabled && new_value
      ::ChatDemo::Cast.seed!
      ::ChatDemo::ChannelSetup.ensure!
      ::Jobs.enqueue(::Jobs::ChatDemo::GenerateScript)
    end
  end
end
