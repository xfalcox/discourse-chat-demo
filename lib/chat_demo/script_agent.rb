# frozen_string_literal: true

module ::ChatDemo
  # A Discourse AI agent that writes the daily conversation script. It owns the
  # Google search tool and decides for itself when to search for game news, so
  # the plugin never calls Discourse AI's internals directly.
  #
  # The agent's structured-output helper only supports arrays of primitives, so
  # each message is emitted as a single "username: message" string; the generator
  # splits it back into the two stored columns.
  class ScriptAgent < DiscourseAiCompat.agent_class
    def self.default_enabled
      false
    end

    def tools
      [DiscourseAiCompat.google_tool_class].compact
    end

    def system_prompt
      game = SiteSetting.chat_demo_game_name
      roster =
        Cast::ROSTER
          .map { |c| "- #{c[:username]} (#{c[:name]}): #{c[:bio]}" }
          .join("\n")

      <<~PROMPT
        You are a scriptwriter generating a realistic, casual group chat for an online gaming
        community's Discord-style channel about the game "#{game}". The conversation should feel
        live and unscripted: short messages (usually one sentence), lowercase is fine, light slang
        and the occasional emoji are welcome. Mix banter, in-jokes, questions and answers, reactions
        to recent news, and the ordinary chatter of people hanging out.

        Use the google tool to look up recent news, updates, and patches about "#{game}" so the
        conversation feels current. React to what you find naturally — do not quote articles verbatim.

        The cast (use ONLY these usernames, never invent participants):
        #{roster}

        Hard rules:
        - Do not @-mention usernames that are not in the cast above.
        - Keep each message believable as a single chat line — no multi-paragraph posts.
        - No narration, stage directions, or timestamps.
        - Spread the conversation naturally across all the participants.

        Output format:
        - Return the "messages" array, in conversation order.
        - Each array item is one chat line formatted EXACTLY as "username: message"
          (the username, then a colon and a space, then the message text).
      PROMPT
    end

    def response_format
      [{ "key" => "messages", "type" => "array", "array_type" => "string" }]
    end
  end
end
