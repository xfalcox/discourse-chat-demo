# frozen_string_literal: true

class CreateChatDemoMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_demo_messages do |t|
      t.string :username, null: false
      t.text :message, null: false
      t.datetime :sent_at, null: true
      t.timestamps
    end

    # The dispatcher repeatedly asks for the oldest unsent line, so index the
    # play order restricted to unsent rows.
    add_index :chat_demo_messages,
              :id,
              name: "index_chat_demo_messages_unsent",
              where: "sent_at IS NULL"
  end
end
