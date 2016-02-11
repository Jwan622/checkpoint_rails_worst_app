module AuthorHelper
  def cache_key_for_authors
    count          = Author.count
    max_updated_at = Author.maximum(:updated_at).try(:utc).try(:to_s, :number)
    "authors/all-#{count}-#{max_updated_at}"
  end
end
