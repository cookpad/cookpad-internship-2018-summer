require 'set'
require 'faye/websocket'

class ChatApp
  class ChatMessageError < StandardError; end

  SYSTEM_NAME = "slackpad"

  attr_reader :users

  def initialize
    @users = {}
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env)

      ws.on :open do |event|
        Rails.logger.debug("Open #{ws}")
      end

      ws.on :message do |event|
        Rails.logger.debug("Message #{ws}: #{event.data}")
        process_message(event)
      end

      ws.on :close do |event|
        Rails.logger.debug("Close #{ws}: #{event.code}")
        users.delete(ws)
        ws = nil
      end

      ws.rack_response
    else
      [200, {'Content-Type' => 'text/plain'}, ['Hello']]
    end
  end

  private

  def process_message(event)
    ws = event.current_target
    prefix, command, params = parse_message(event.data)
    case command
    when :user
      username = params[0]
      users[ws] = username
      reply(ws, username, :user, [username])
    when :join
      # TODO
    when :part
      # TODO
    when :message
      username = users[ws]
      channel_name = params[0]
      text = params[1]
      channel = Channel.find_by!(name: "general")
      users.keys.each do |user_ws|
        reply(user_ws, username, :message, params)
      end
      channel.messages.create!(nickname: username, message: text)
    when :list
      # TODO
    else
      raise ChatMessageError, "Unknown command: #{command}"
    end
  rescue ChatMessageError => e
    reply(ws, SYSTEM_NAME, :error, [e.message])
  rescue => e
    Rails.logger.error(e.message)
    Rails.logger.error(e.backtrace.join("\n"))
    reply(ws, SYSTEM_NAME, :error, [e.message])
  end

  def reply(ws, prefix, command, params)
    message = format_message(prefix, command, params)
    ws.send(message)
  end

  def parse_message(message)
    match = /\A(?:(?<prefix>) )?(?<command>\w+) (?<params>.+)\z/.match(message)
    unless match
      raise ChatMessageError, "Invalid format message: #{message}"
    end
    [match[:prefix], match[:command].to_sym, JSON.parse(match[:params])]
  rescue JSON::ParserError
    raise ChatMessageError, "Invalid format argument: #{match[:params]}"
  end

  def format_message(prefix = nil, command, params)
    "#{ prefix ? ":#{prefix} " : "" }#{command} #{JSON.dump(params)}"
  end
end
