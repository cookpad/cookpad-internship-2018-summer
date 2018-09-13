module Hello
  class HealthsController < ApplicationController
    def show
      render json: { 'status' => 'healthy' }
    end
  end
end
