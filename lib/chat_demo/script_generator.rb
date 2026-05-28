# frozen_string_literal: true

module ::ChatDemo
  # Drives the ScriptAgent to produce a fresh day's worth of conversation, then
  # replaces the contents of the chat_demo_messages table in one transaction.
  # All Discourse AI interaction goes through the agent/bot abstraction; the
  # agent owns the Google tool and runs the search-and-reason loop itself.
  module ScriptGenerator
    class NoLlmConfigured < StandardError
    end

    def self.run!
      raise NoLlmConfigured unless DiscourseAiCompat.available?

      llm_model = resolve_llm_model
      raise NoLlmConfigured if llm_model.nil?

      output = reply(llm_model)
      lines = parse(output)

      replace_script!(lines)
      lines.size
    end

    def self.resolve_llm_model
      model_id = SiteSetting.ai_default_llm_model.to_s.split(":").last
      return nil if model_id.blank?

      LlmModel.find_by(id: model_id)
    end

    def self.reply(llm_model)
      context =
        DiscourseAiCompat.bot_context_class.new(
          user: Discourse.system_user,
          skip_show_thinking: true,
          feature_name: "chat_demo_script",
          messages: [{ type: :user, content: task_message }]
        )

      agent = ScriptAgent.new
      bot =
        DiscourseAiCompat.bot_class.as(
          Discourse.system_user,
          agent: agent,
          model: llm_model
        )

      structured_output = nil
      bot.reply(context) do |partial, _, type|
        structured_output = partial if type == :structured_output
      end
      structured_output
    end

    def self.task_message
      game = SiteSetting.chat_demo_game_name
      count = SiteSetting.chat_demo_script_lines

      <<~MSG
        Search for the latest news and updates about "#{game}", then write about #{count} chat
        messages as an ordered, casual conversation between the cast reacting to it and chatting
        generally. Remember: each item in "messages" must be formatted as "username: message".
      MSG
    end

    # The agent returns an array of "username: message" strings; split each on the
    # first colon and keep only lines naming a real cast member.
    def self.parse(structured_output)
      return [] if structured_output.blank?

      raw = structured_output.read_buffered_property(:messages)
      allowed = Cast.usernames.map(&:downcase).to_set

      Array(raw).filter_map do |entry|
        username, message = entry.to_s.split(":", 2)
        username = username.to_s.strip
        message = message.to_s.strip
        next if username.blank? || message.blank?
        next if allowed.exclude?(username.downcase)

        { username: username, message: message }
      end
    end

    def self.replace_script!(lines)
      now = Time.zone.now
      rows =
        lines.map do |line|
          {
            username: line[:username],
            message: line[:message],
            created_at: now,
            updated_at: now
          }
        end

      Message.transaction do
        Message.delete_all
        Message.insert_all(rows) if rows.any?
      end
    end
  end
end
