require "rails_helper"

RSpec.describe "API", type: :request do
  describe "GET /channels" do
    before do
      Channel.create!(name: "foobar")
    end

    it "success" do
      get "/channels"
      expect(response).to be_successful
      expect(response.body).to be_json_including([
        { name: "foobar" },
        { name: "general" },
      ])
    end
  end

  describe "GET /channels/:channel_id/messages" do
    let(:channel) { Channel.find_by!(name: "general") }
    before do
      channel.messages.create!(nickname: "superman", message: "hello!")
    end

    it "success" do
      get "/channels/#{channel.id}/messages"
      expect(response).to be_successful
      expect(response.body).to be_json_including([
        { nickname: "superman", message: "hello!" },
        { nickname: "slackpad", message: "ようこそ、こんにちは！" },
      ])
    end
  end

  describe "POST /channels/:channel_id/messages" do
    let(:channel) { Channel.find_by!(name: "general") }

    it "success" do
      post "/channels/#{channel.id}/messages", params: { nickname: "rrreeeyyy", message: "hello!" }
      expect(response).to be_successful
      expect(response.body).to be_json_including(message: "hello!")
    end
  end

  describe "GET /images/:id" do
    let(:image) { Image.create!(filename: "beaf.png", data: Base64.encode64("deadbeaf")) }

    it "success" do
      get "/images/#{image.id}"
      expect(response).to be_successful
      expect(response.body).to eq("deadbeaf")
    end
  end

  describe "POST /images" do
    it "success" do
      post "/images", params: { filename: "beaf.png", data: Base64.encode64("deadbeaf") }
      expect(response).to be_successful
      expect(response.body).to be_json_including(filename: "beaf.png")
    end
  end
end
