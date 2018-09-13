class ImagesController < ApplicationController
  def show
    image = Image.find(params[:id])
    send_data image.decode, type: image.content_type, disposition: :inline
  end

  def create
    image = Image.create!(filename: params[:filename], data: params[:data])
    render json: JSON.dump(image.serializable_hash(except: :data))
  end
end
