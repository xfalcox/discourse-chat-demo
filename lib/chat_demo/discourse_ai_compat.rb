# frozen_string_literal: true

module ::ChatDemo
  # Thin shim over Discourse AI so the plugin keeps working across the
  # Personas -> Agents rename. Mirrors plugins/hosted-site.
  module DiscourseAiCompat
    def self.agent_class
      if defined?(DiscourseAi::Agents::Agent)
        DiscourseAi::Agents::Agent
      elsif defined?(DiscourseAi::Personas::Persona)
        DiscourseAi::Personas::Persona
      end
    end

    def self.bot_class
      if defined?(DiscourseAi::Agents::Bot)
        DiscourseAi::Agents::Bot
      elsif defined?(DiscourseAi::Personas::Bot)
        DiscourseAi::Personas::Bot
      end
    end

    def self.bot_context_class
      if defined?(DiscourseAi::Agents::BotContext)
        DiscourseAi::Agents::BotContext
      elsif defined?(DiscourseAi::Personas::BotContext)
        DiscourseAi::Personas::BotContext
      end
    end

    def self.google_tool_class
      if defined?(DiscourseAi::Agents::Tools::Google)
        DiscourseAi::Agents::Tools::Google
      elsif defined?(DiscourseAi::Personas::Tools::Google)
        DiscourseAi::Personas::Tools::Google
      end
    end

    def self.available?
      bot_class.present? && bot_context_class.present?
    end
  end
end
