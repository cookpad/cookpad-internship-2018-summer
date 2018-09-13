class ChannelsController < ApplicationController
  def index
    render json: JSON.dump(Channel.page(params[:page]).per(params[:per_page]).order(created_at: :desc).map(&:serializable_hash))
  end
end
