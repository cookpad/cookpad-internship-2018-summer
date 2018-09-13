class CreateMessages < ActiveRecord::Migration[5.2]
  def change
    create_table :messages do |t|
      t.integer     :channel_id,              null: false
      t.string      :nickname,   limit: 100,  null: false
      t.string      :message,    limit: 5000, null: false
      t.timestamps                            null: false
    end
  end
end
