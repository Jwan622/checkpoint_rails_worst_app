class AddIndexToArticles < ActiveRecord::Migration
  def change
    add_index :articles, :author_id
  end
end
