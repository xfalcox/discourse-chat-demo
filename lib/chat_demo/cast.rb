# frozen_string_literal: true

module ::ChatDemo
  # The fixed cast of demo users the generated scripts are allowed to speak as.
  # The script generator is constrained to these usernames so every generated
  # line maps to a real, pre-seeded user.
  module Cast
    CUSTOM_FIELD = "chat_demo_bot"

    ROSTER = [
      {
        username: "vex_dives",
        name: "Vex",
        bio: "Tries every build the wiki says is bad. Sometimes they're not."
      },
      {
        username: "mara_tk",
        name: "Mara",
        bio: "Patch notes enjoyer. Will read you the changelog unprompted."
      },
      {
        username: "soup",
        name: "soup",
        bio: "Mostly here for the screenshots. Occasionally lands a clutch."
      },
      {
        username: "bigtoad",
        name: "BigToad",
        bio: "Has 2,000 hours and zero chill. Loves a good meta argument."
      },
      {
        username: "kestrel99",
        name: "Kestrel",
        bio: "New-ish, asks the good questions everyone was afraid to ask."
      },
      {
        username: "doc_pylon",
        name: "Doc",
        bio: "The unofficial support main. Theorycrafts in spreadsheets."
      },
      {
        username: "nyx_afk",
        name: "Nyx",
        bio: "Lurker turned poster. Drops one perfect joke per evening."
      },
      {
        username: "rook_tactical",
        name: "Rook",
        bio: "Squad caller. Talks objectives, callouts, and positioning."
      }
    ].freeze

    def self.usernames
      ROSTER.map { |character| character[:username] }
    end

    def self.users
      User.where(username_lower: usernames.map(&:downcase))
    end

    # Idempotent: safe to call on every enable.
    def self.seed!
      ROSTER.map { |character| find_or_create(character) }
    end

    def self.find_or_create(character)
      existing = User.find_by(username_lower: character[:username].downcase)
      return existing if existing

      user =
        User.new(
          username: character[:username],
          name: character[:name],
          email: "#{character[:username]}@chat-demo.invalid",
          password: SecureRandom.hex(32),
          active: true,
          approved: true,
          trust_level: TrustLevel[1]
        )
      user.skip_email_validation = true
      user.save!

      user.activate
      user.custom_fields[CUSTOM_FIELD] = true
      user.save_custom_fields

      # These accounts have @chat-demo.invalid emails — make sure nothing ever
      # tries to email them (digests, mentions, messages would all bounce).
      never = UserOption.email_level_types[:never]
      user.user_option.update!(
        mailing_list_mode: false,
        email_digests: false,
        email_level: never,
        email_messages_level: never
      )

      if character[:bio].present?
        user.user_profile.update!(bio_raw: character[:bio])
      end

      user
    end
  end
end
