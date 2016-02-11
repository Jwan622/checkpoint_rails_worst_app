class AuthorController < ApplicationController

  def index
    @authors = Author.paginate(:page => params[:page], :per_page => 30).includes(:articles)
  end
end
