require "rails_helper"
require "websocket-client-simple"

RSpec.describe "Chat", type: :feature do
  let(:url) { "http://#{page.server.host}:#{page.server.port}/ws" }
  let(:ws) { WebSocket::Client::Simple.connect(url) }
  around do |example|
    ObjectSpace.each_object(ChatApp) do |app|
      app.send(:initialize)
    end
    $ws_messages = []
    ws.on :message do |event|
      $ws_messages << event.data
    end
    until ws.open?
      sleep 0.01
    end

    begin
      example.run
    ensure
      ws.close
    end
  end

  describe "user command" do
    it "success" do
      ws.send('user ["hogelog"]')
      sleep 0.1
      expect($ws_messages).to eq([
        ':hogelog user ["hogelog"]',
        ':hogelog join ["general"]',
      ])
    end
  end

  describe "join command" do
    it "success" do
      ws.send('user ["hogelog"]')
      ws.send('join ["foobar"]')
      sleep 0.1
      expect($ws_messages).to eq([
        ':hogelog user ["hogelog"]',
        ':hogelog join ["general"]',
        ':hogelog join ["foobar"]',
      ])
      expect(Channel.pluck(:name)).to match_array(["general", "foobar"])
    end
  end

  describe "part command" do
    it "success" do
      ws.send('user ["hogelog"]')
      ws.send('join ["foobar"]')
      ws.send('part ["foobar"]')
      sleep 0.1
      expect($ws_messages).to eq([
        ':hogelog user ["hogelog"]',
        ':hogelog join ["general"]',
        ':hogelog join ["foobar"]',
        ':hogelog part ["foobar"]',
      ])
    end
  end

  describe "message command" do
    it "success" do
      ws.send('user ["hogelog"]')
      ws.send('message ["general", "hello general!"]')
      ws.send('join ["foobar"]')
      ws.send('message ["foobar", "hello foobar!"]')
      sleep 0.1
      expect($ws_messages).to eq([
        ':hogelog user ["hogelog"]',
        ':hogelog join ["general"]',
        ':hogelog message ["general","hello general!"]',
        ':hogelog join ["foobar"]',
        ':hogelog message ["foobar","hello foobar!"]',
      ])
    end
  end

  describe "list command" do
    it "success" do
      ws.send('user ["hogelog"]')
      ws.send('list ["general"]')
      ws.send('join ["foobar"]')
      ws.send('list ["foobar"]')
      ws.send('part ["foobar"]')
      ws.send('list ["foobar"]')
      sleep 0.1
      expect($ws_messages).to eq([
        ':hogelog user ["hogelog"]',
        ':hogelog join ["general"]',
        ':slackpad list ["general",["hogelog"]]',
        ':hogelog join ["foobar"]',
        ':slackpad list ["foobar",["hogelog"]]',
        ':hogelog part ["foobar"]',
        ':slackpad list ["foobar",[]]',
      ])
    end
  end
end
