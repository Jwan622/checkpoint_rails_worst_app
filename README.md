# Worst performing app ever. Let's learn how to fix this mess.

1. Git clone this app and follow the instructions below.

```bash
git clone git@github.com:Jwan622/worst_app_tutorial.git
```
### This is a tutorial on performance optimizations in caching, ActiveRecord querying,

So, first step is to run bundler and download all the necessary gems and its dependencies.

```
bundle install
```

and then run this app locally:

```
rails server
```

Let's visit our homepage at localhost.

Currently, the home page takes this long to load:

```bash
...(there are a ton of database queries above this)... like a few thousand NBD)
Article Load (0.5ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 3000]]
Article Load (0.5ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 3001]]
Rendered author/index.html.erb within layouts/application (9615.5ms)
Completed 200 OK in 9793ms (Views: 7236.5ms | ActiveRecord: 2550.1ms)
```

The view takes 7.2 seconds to load. The AR querying takes 2.5 second to load. The page takes close to 10 seconds to load. That's not great at all... in fact, that's just awful.

The stats page is even worse:

```bash
Rendered stats/index.html.erb within layouts/application (9.9ms)
Completed 200 OK in 16197ms (Views: 38.0ms | ActiveRecord: 4389.4ms)
```

It took 16 seconds to load and a lot of the time taken isn't even in the ActiveRecord querying or the view (those add to like 1/3rd of the total time). It's the creation of ruby objects that is taking a lot of time. This will be explained in further detail below.

So, **What can we do?**

Well, let's focus on improving time it takes for the view to load and the AR querying first!

Complete this tutorial first:
[Jumpstart Lab Tutorial on Querying](http://tutorials.jumpstartlab.com/topics/performance/queries.html)

# Things we will do today!
* Add an index to the correct columns
* Implement eager loading vs lazy loading on the right pages.
* Replace Ruby lookups with ActiveRecord methods.
* Fix html_safe issue.
* Page cache or fragment cache the root page.
* The root page needs to implement eager loading, pagination, and fragment caching.

##### Index some columns. But what should we index?

[great explanation of how to index columns and when](http://tutorials.jumpstartlab.com/topics/performance/queries.html#indices)

Our non-performant app has a few columns where indexing would give us a clear performance benefit. How do we know this? Well, the associations between articles and authors, and authors and comments implies that lookups will occur in our application between articles and authors, and authors and comments. Those lookups will rely on the author_id and comment_id columns which are the foreign keys. Let's think about indexing those foreign keys.

```ruby
class Article < ActiveRecord::Base
  belongs_to :author
  has_many :comments
end
```

##### Ruby vs ActiveRecord

One of the reasons why the time for a view to render is longer than the sum of its ActiveRecord and view creation parts is due to Ruby object creation. Let's take a look at this problem.

Let's try to get some ids from our Article model.

Look at Ruby:

```ruby
puts Benchmark.measure {Article.select(:id).collect{|a| a.id}}
  Article Load (2.6ms)  SELECT "articles"."id" FROM "articles"
  0.020000   0.000000   0.020000 (  0.021821)
```

Note that the Article.select(:id) is an AR method that retrieves only the :id field and returns an AR Relation object but the collect/map is a Ruby method that creates an enumerator. The time jump when you create the enumerator is large. That object creation is costly in terms of time.

The real time is 0.027821 for the Ruby query.

vs ActiveRecord

```ruby
puts Benchmark.measure {Article.pluck(:id)}
   (3.2ms)  SELECT "articles"."id" FROM "articles"
  0.000000   0.000000   0.000000 (  0.006992)
```
The real time is 0.006992 for the pure AR query. The Ruby query is about 300%+ slower.

For example, this code is terribly written in the Author model:

```ruby
def self.most_prolific_writer
  all.sort_by{|a| a.articles.count }.last
end

def self.with_most_upvoted_article
  all.sort_by do |auth|
    auth.articles.sort_by do |art|
      art.upvotes
    end.last
  end.last
end
```

Both methods use Ruby methods (sort_by) which leads to Ruby object creation instead of most time efficient ActiveRecord queries. Let's fix that!

##### html_safe makes it unsafe or safe?.

This is why variable and method naming is important.

In the show.html.erb for articles, we have this code

```ruby
  <% @articles.comments.each do |com| % >
    <%= com.body.html_safe %>
  <% end %>
```

What's wrong with it?

The danger is if comment body are user-generated input...which they are.

See [here](http://stackoverflow.com/questions/4251284/raw-vs-html-safe-vs-h-to-unescape-html)

Understand now? Fix the problem.


##### Caching

Our main view currently takes 4 seconds to load

```bash
Rendered author/index.html.erb within layouts/application (5251.7ms)
Completed 200 OK in 5269ms (Views: 4313.1ms | ActiveRecord: 955.6ms)
```

Let's fix that. Read this:
[fragment caching](http://guides.rubyonrails.org/caching_with_rails.html#fragment-caching)
