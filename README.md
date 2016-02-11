# Worst performing app ever. Let's learn how to fix this mess.

Git clone this app and follow the instructions below.

```bash
git clone git@github.com:Jwan622/worst_app_tutorial.git
```

and switch to the branch called tutorial_start.

### This is a tutorial on performance optimizations in caching, ActiveRecord querying,

So, first step is to run bundler and download all the necessary gems and its dependencies.

```
bundle install
```

Then migrate your database and seed it.

```rails
rake db:migrate
rake db:seed
```

and then run this app locally:

```
rails server
```

Let's visit the homepage locally.

Currently, the home page takes forever to load:

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

#### Things we will do today!
* Add an index to the correct columns.
* Learn about eager loading vs lazy loading and implement eager loading on the right pages.
* Replace Ruby lookups with ActiveRecord methods.
* Fragment cache the root page.

##### Index some columns. But what should we index? And what is indexing?

Wikipedia states that ‘a database index is a data structure that improves the speed of operations on a database table’. Unfortunately, this improvement comes at a cost.
A database index is exactly what it sounds like. If you think of the index at the back of a reference book: a quickly searchable list of pointers to get to the actual data. Without an index, a database query might have to look at every row in your database table to find the correct result.

[great explanation of how to index columns and when](http://tutorials.jumpstartlab.com/topics/performance/queries.html#indices)

Our non-performant app has a few columns where indexing would give us a clear performance benefit. How do we know this? Well, the associations between articles and authors, and authors and comments implies that lookups will occur in our application between authors and articles, and articles and comments. Those lookups will rely on the author_id and article_id columns which are the foreign keys on the articles and comments tables respectively. Let's think about indexing those foreign keys.

**Questions**:
**How does indexing work?**
- Database indices typically use binary search, using B-trees or similar, which offers a good balance between storage costs and time for retrieval and update. When a database is told to keep an index on a column, an ordered list (a binary tree technically) is created that gives the database a faster way to search for certain values in that column.

**Why wouldn't we index every column?**
- Unfortunately, indices don’t come for free. Each insert to the table will incur extra processing to maintain the index. For this reason, indexes should only be added to columns that are actually queried in the application.

Adding an index on author_id on the articles table will improve the speed of the author.articles query significantly. Let's do it!

[how does database indexing work?](http://stackoverflow.com/questions/1108/how-does-database-indexing-work)
[binary search complexity](http://stackoverflow.com/questions/8185079/how-to-calculate-binary-search-complexity)

#### Eager loading vs lazy loading. When should we use includes? What is an N+1 query problem?

So, what is an N+1 problem anyway?

Let's take a look at our root page again. Refresh the root page and look at the SQL queries that are lgoged in our console.

```
Author Load (43.3ms)  SELECT "authors".* FROM "authors"
  Article Load (0.9ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 1]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 2]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 3]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 4]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 5]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 6]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 7]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 8]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 9]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 10]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 11]]
  Article Load (0.1ms)  SELECT "articles".* FROM "articles" WHERE "articles"."author_id" = ?  [["author_id", 12]]
  ... (like 3000 more articles)
```

The first line of this massive log is this:

```
Author Load (43.3ms)  SELECT "authors".* FROM "authors"
```

That SQL query is getting all of the authors from the authors table. Where is it coming from? It is fired from the controller from this line:

```
Author.all
```

Even though that query is grabbing all of the authors from the authors table, it's only one query and that in itself is not the problem. The bigger problem occurs in the view:

```html
@authors.each do |author| %>
  ...
    <% author.articles.each
```

So for each author, we're grabbing all of the articles associated with the author from the database.
And remember, we have a lot of authors:
```
Author.count
   (0.2ms)  SELECT COUNT(*) FROM "authors"
 => 3001
```

So we're grabbing all of the articles for all 3001 authors. So if we have N authors, we have to make N queries to grab their articles + the original 1 query that obtained all of the authors in the controller. Hence, N+1.

The problem with this is that each query has quite a bit of overhead. It is much faster to issue 1 query which returns 100 results than to issue 100 queries which each return 1 result. This is particularly true if your database is on a different machine which is, say, 1-2 milliseconds away on the network. In this case, issuing 100 queries serially has a minimum cost of 100-200ms, even if they can be satisfied instantly by your database.

Our bullet gem detects N+1 loading, and unused eager loading and fires a Javascript popup when on an inefficient page. It's super useful in development!

Anyway, let's try to fix our N+1 problem by implement eager loading. What is eager loading?
- Normally, when you retrieve a model from the database that has related models, the related models are generally loaded on demand.
- Eager loading is a way to reduce the number of queries being made. Instead of querying the associated table on demand, we load a has_many association in one swoop. These are then resident in memory, with relationships in tact, so you don't need to make another database call to get them. In other words, when querying a table for data with an associated table, both tables are loaded into memory which in turn reduce the amount of database queries required to retrieve any associated data.

[includes vs joins](http://tomdallimore.com/blog/includes-vs-joins-in-rails-when-and-where/)
[railscast](http://railscasts.com/episodes/22-eager-loading-revised)
**Why wouldn't you implement eager loading all the time?**
- Answer: it's costly to eager load and it takes longer to store the results in memory. Writing to memory takes time. So the problem is what if you go to a page that doesn't need to ever ask for associations between articles and authors.

**Why would you ever index a column and not eager load an entire table? When we eager load an associated table, we no longer actually query that database and so the benefits of indexing are lost. So why would we ever do index a column and not eager load?**
- Answer: Well sometimes we don't need all the articles for a spefici author. What if we just need the last article by an author. That's still doing a lookup on the author_id column in the articles table and since it isn't doing an N+1 query  there's no need to do a more expensive eager loading type query which is more expensive than simply finding the last article for a specific author.


##### Ruby vs ActiveRecord

Let's take a look at two hypothetical queries:

```rails
Articles.all.map(&:author_id)
Articles.pluck(:author_id)
```

map (a.k.a. collect) is another useful Array method. Unfortunately, that’s just the problem. Because it works on arrays, Rails needs to select all the columns to instantiate a model for each row, when all we really want is a single column. In the example above, all the columns from the articles table are selected, even though we’re only after the author_id.

With the pluck method, only that single column is selected from the table, and no models are instantiated.

Let's try to get some ids from our Article model.

Look at Ruby:

```ruby
puts Benchmark.measure {Article.select(:id).collect{|a| a.id}}
  Article Load (2.6ms)  SELECT "articles"."id" FROM "articles"
  0.020000   0.000000   0.020000 (  0.021821)
```

Note that the Article.select(:id) is an ActiveRecord method that retrieves all the objects but only with the :id field. This select is different from the Ruby select; this ActiveRecord select actually modifies the SELECT statement for SQL queries. But, collect/map is a Ruby method that creates an enumerator. The time cost when you create the enumerator is large. That Ruby object creation is costly.

The real time is 0.021821 for the Ruby query.

vs ActiveRecord

```ruby
puts Benchmark.measure {Article.pluck(:id)}
   (3.2ms)  SELECT "articles"."id" FROM "articles"
  0.000000   0.000000   0.000000 (  0.006992)
```
The real time is 0.006992 for the pure ActiveRecord query. The Ruby query is about 300%+ slower.

Let's take a look at our terribly written code in the Author model:

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

Both methods use Ruby methods (sort_by) which leads to Ruby object creation instead of more time efficient ActiveRecord queries. Let's fix that!

#### Paginate
Let's work on the view. The root page is loading like 3001 records. Fetching 3001 records from a database is a problem and so is creating all 3001 objects. Let's paginate our app. What is pagination? It's a way to only display a set number of items per page with links to other pages. Honestly, this would have been the best solution from the get go.

Let's use the will_paginate gem. This is literally the easiest thing to implement ever! Let's take a look at it!

[will_paginate gem](https://github.com/mislav/will_paginate)
[will_paginate tutorial](https://hackhands.com/pagination-rails-will_paginate-gem/)

##### Caching

Caching means to store content generated during the request-response cycle and to reuse it when responding to similar requests.

So why cache? The answer is simple. Speed. With Ruby, we don't get speed for free because our language isn't very fast to begin with 22 Ruby performance in the Benchmarks Game vs Javascript. . We have to get speed from executing less Ruby on each request. The easiest way to do that is with caching. Do the work once, cache the result, serve the cached result in the future.

Our main view currently takes 4 seconds to load

```bash
Rendered author/index.html.erb within layouts/application (5251.7ms)
Completed 200 OK in 5269ms (Views: 4313.1ms | ActiveRecord: 955.6ms)
```

Let's try to implement fragment caching.

Let's fix that. Read this:
[great tutorial](https://www.nateberkopec.com/2015/07/15/the-complete-guide-to-rails-caching.html)
[fragment caching](http://guides.rubyonrails.org/caching_with_rails.html#fragment-caching)
[railscast on caching](http://railscasts.com/episodes/90-fragment-caching-revised?view=comments)

#### Lastly, try to find some other problems and implement other solutions

- There's a nasty html_safe method on a form somewhere which will just allow you to insert Javascript scripts.
- Work on the stats page! Paginate it and implement eager loading... if you need it...
