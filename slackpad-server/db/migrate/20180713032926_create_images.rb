class CreateImages < ActiveRecord::Migration[5.2]
  def change
    create_table :images do |t|
      t.string      :filename, limit: 100, null: false
      t.text        :data,                 null: false
      t.timestamps                         null: false
    end
  end
end
