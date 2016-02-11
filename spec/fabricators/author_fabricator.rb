Fabricator(:author) do
  name { Faker::Name.name }
  articles(count: 1)
end
