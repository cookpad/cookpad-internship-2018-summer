# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
general = Channel.find_or_create_by!(name: "general")

if Message.count == 0
  general.messages.create!(nickname: ChatApp::SYSTEM_NAME, message: "ようこそ、こんにちは！")
end
