1. checkout the start_here branch

2. go over gemfile, use fabrication and faker.
3. if needed, go over fabricator gem http://www.fabricationgem.org/
4. go over schema, simple database structure. go over models to see what belongs to what.
5. go over routes
6. go over author index page
7. go over stats page. The length of the querying is due to this:

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

So where are all the queries coming from?
- The five_longest_article_names has an all query
- Author.most_prolific_writer also has an all query.
- Author.with_most_upvoted_article also has an all query
- Article.all_names has an all query

Is it the all query? Actually no. If you go into rails console and type:

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

because that query suffers from an N+1. Why is it called N+1?
