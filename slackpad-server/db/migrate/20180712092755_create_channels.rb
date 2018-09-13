class CreateChannels < ActiveRecord::Migration[5.2]
  def change
    create_table :channels do |t|
      t.string      :name, limit: 100, null: false
      t.timestamps                     null: false
    end
  end
end
