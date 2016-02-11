### Intro
- Tell people to checkout the tutorial_start branch.
- Quickly go over the gemfile, explain usage fabrication and faker (basically to make a huge app quickly with a ton data).
- If needed, go over fabricator gem http://www.fabricationgem.org/
- Go over schema, simple database structure. go over models to see what belongs to what.
- Go over routes
- Go over author index page
- Go over stats page. The length of the querying is due to this:

```
class StatsController < ApplicationController
  def index
    @five_longest_article_names = Article.five_longest_article_names
    @prolific_author = Author.most_prolific_writer
    @author_with_most_upvoted_article = Author.with_most_upvoted_article
    @article_names = Article.all_names
    @short_articles = Article.articles_with_names_less_than_20_char
  end
end
```


### N+1 problems.

So where are all the N+1 queries coming from?
Is it the all of the .all calls? Actually no. If you go into rails console and type:

```
Article.all
```

you see that it fires this query:

```
SELECT "articles".* FROM "articles"
```

That's only one query.

These two queries are big culprits when it comes to database querying:

```rails
Author.most_prolific_writer
```

because that query suffers from an N+1 problem.

Question: Why is it called N+1?

#### Adding Indices to columns
So one way we can speed up the time here is by adding an index to the articles table. Database tables without indices will degrade in performance as more records get added to them over time. The more records added to the table, the more the database engine will have to look through to find what it’s looking for. Adding an index to a table will ensure consistent long-term performance in querying against the table even as many thousands of records get added to it (I believe a b-tree allows searches and insertions in O(log n) time complexity).

```
rails g migration AddIndexToArticles
```

```rails
class AddIndexToArticles < ActiveRecord::Migration
  def change
    add_index :articles, :author_id
  end
end
```

Adding an index on author_id will improve the speed of the query significantly.

Questions: Why wouldn't we index every column? How does indicing work?
- Answer : Unfortunately, indices don’t come for free. Each insert to the table will incur extra processing to maintain the index. For this reason, indices should only be added to columns that are actually queried in the application. ‘a database index is a data structure that improves the speed of operations on a database table’. Unfortunately, this improvement comes at a cost.


### Eager loading

Question, so why wouldn't you eager load all the time?
- Answer: it's costly to eager load and it takes longer to store the results in memory. Writing to memory takes time. So the problem is what if you go to a page that doesn't need to ever ask for associations between articles and authors.

Question: Why would you ever index a column? We kind of just showed that the eager loading of two tables was way faster than indexing a column. So why would we ever do index a column?
- Answer: Well sometimes we don't need all the articles for a spefici author. What if we just need the last article by an author. That's still doing a lookup on the author_id column in the articles table and since it isn't doing an N+1 query  there's no need to do a more expensive eager loading type query which is more expensive than simply finding the last article for a specific author.


### ActiveRecord querying
**Articles model:**
scope :five_longest_article_names, -> { order("length(name) DESC").limit(5).pluck(:name) }
scope :all_names, -> { pluck(:name) }
scope :articles_with_names_less_than_20_char, -> { where("length(name) < ?", 20) }


**Author**
scope :most_prolific_writer, -> { order("articles_count DESC").limit(1) }
scope :with_most_upvoted_article, -> { joins(:articles).where("articles.upvotes").order("articles.upvotes DESC").limit(1).pluck(:name) }



### Pagination

```rails
gem 'will_paginate', '~> 3.0.6'
```

Author controller:
```rails
class AuthorController < ApplicationController
  def index
    @authors = Author.paginate(:page => params[:page], :per_page => 30).includes(:articles)
  end
end
```

author/index.html.erb
```html
<%= will_paginate @authors %>

<div class="author">
  <% @authors.each do |author| %>

      <h2>My name is <%= author.name %></h2>
      <% author.articles.each do |art| %>
        <p>I wrote: <span style="text-decoration: underline"><%= link_to art.name, articles_show_path(art) %> </span></p>
      <% end %>

  <% end %>
</div>

<%= will_paginate @authors %>
```


#### Caching

<% cache("authors #{@authors.current_page}") do %>
  <div class="author">
    <% @authors.each do |author| %>
      <% cache(author) do %>
        <div class="author_card">
          <h2>My name is <span class="author_name"><%= author.name %></span></h2>
          <div class="articles">I wrote:
            <ul>
              <% author.articles.each do |art| %>
                <% cache(art) do %>
                  <li><span style="text-decoration: underline"><%= link_to art.name, articles_show_path(art.id) %> </span>
                  </li>
                  <% end %>
              <% end %>
            </ul>
        </div>
      </div>
      <% end %>
    <% end %>
  </div>
<% end %>
