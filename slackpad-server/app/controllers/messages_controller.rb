class MessagesController < ApplicationController
  def create
    message = Channel.find(params[:channel_id]).messages.create!(nickname: params[:nickname], message: params[:message])
    render json: JSON.dump(message.serializable_hash)
  end
end
