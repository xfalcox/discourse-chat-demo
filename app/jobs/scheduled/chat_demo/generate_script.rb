# frozen_string_literal: true

module ::Jobs
  module ChatDemo
    # Once a day, refresh the conversation script with fresh, news-aware content.
    class GenerateScript < ::Jobs::Scheduled
      every 1.day
      cluster_concurrency 1

      def execute(_args)
        return unless SiteSetting.chat_demo_enabled

        ::ChatDemo::ChannelSetup.ensure!
        ::ChatDemo::ScriptGenerator.run!
      rescue ::ChatDemo::ScriptGenerator::NoLlmConfigured
        Rails.logger.warn(
          "discourse-chat-demo: no default LLM configured (ai_default_llm_model); skipping script generation"
        )
      end
    end
  end
end
