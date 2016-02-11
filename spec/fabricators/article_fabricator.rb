Fabricator(:article) do
  name { Faker::Lorem.sentence }
  body { Faker::Lorem.paragraph }
  comments(count: 1)
end
