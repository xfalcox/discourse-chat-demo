# frozen_string_literal: true

module ::ChatDemo
  # Drives a Discourse AI agent (the one chosen via chat_demo_agent_id, or the
  # built-in ScriptAgent) to produce a fresh day's worth of conversation, then
  # replaces the contents of the chat_demo_messages table in one transaction.
  # All Discourse AI interaction goes through the agent/bot abstraction; the
  # agent owns the search tool and runs the search-and-reason loop itself.
  module ScriptGenerator
    class NoLlmConfigured < StandardError
    end

    def self.run!
      raise NoLlmConfigured unless DiscourseAiCompat.available?

      agent, llm_model = resolve_agent_and_model
      raise NoLlmConfigured if llm_model.nil?

      output = reply(agent, llm_model)
      lines = parse(output)

      # Never wipe a working script for an empty/garbage generation — keep
      # yesterday's content so the channel stays lively. (A raised API error
      # also leaves the table untouched, since replace_script! isn't reached.)
      if lines.empty?
        Rails.logger.warn(
          "discourse-chat-demo: generation produced no usable lines; keeping the previous script"
        )
        return 0
      end

      replace_script!(lines)
      lines.size
    end

    # Use the agent configured via the chat_demo_agent_id site setting (so the
    # prompt/tools/model can be tuned in the admin UI), falling back to the
    # built-in ScriptAgent. A configured agent may bring its own default LLM.
    def self.resolve_agent_and_model
      agent_id = SiteSetting.chat_demo_agent_id
      record = AiAgent.find_by_id_from_cache(agent_id) if agent_id.present?
      # class_instance returns the agent *class*; instantiate it (nil-safe).
      klass = record&.class_instance

      if klass
        [
          klass.new,
          find_llm(record.default_llm_id || SiteSetting.ai_default_llm_model)
        ]
      else
        [ScriptAgent.new, find_llm(SiteSetting.ai_default_llm_model)]
      end
    end

    def self.find_llm(model_id)
      id = model_id.to_s.split(":").last
      id.present? ? LlmModel.find_by(id: id) : nil
    end

    def self.reply(agent, llm_model)
      context =
        DiscourseAiCompat.bot_context_class.new(
          user: Discourse.system_user,
          skip_show_thinking: true,
          feature_name: "chat_demo_script",
          messages: [{ type: :user, content: task_message }]
        )

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

    # Self-contained so a custom agent configured in the admin UI has everything
    # it needs (game, cast, output shape) without hard-coding any of it.
    def self.task_message
      game = SiteSetting.chat_demo_game_name
      count = SiteSetting.chat_demo_script_lines
      roster =
        Cast::ROSTER
          .map { |c| "- #{c[:username]} (#{c[:name]}): #{c[:bio]}" }
          .join("\n")

      <<~MSG
        Game: #{game}

        You are writing chat for this community's #general channel. Search the web for the latest
        news and updates about "#{game}", then write about #{count} chat messages as an ordered,
        casual conversation reacting to it and chatting generally.

        Use ONLY these usernames (never invent participants):
        #{roster}

        Output the "messages" array in conversation order; each item must be formatted EXACTLY as
        "username: message" (the username, then a colon and a space, then the message text).
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
