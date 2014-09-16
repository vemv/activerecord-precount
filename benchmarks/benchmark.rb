require "benchmark"
require "pry"
require "active_record"
require "activerecord-import"
require "activerecord-has_count"

spec_dir = File.expand_path("../../spec", __FILE__)
Dir[File.join(spec_dir, "models/*.rb")].each { |f| require f }

database_yml = File.join(spec_dir, "database.yml")
ActiveRecord::Base.configurations["bench"] = YAML.load_file(database_yml)["bench"]
ActiveRecord::Base.establish_connection :bench

ActiveRecord::Schema.define do
  create_table :tweets, force: true do |t|
    t.column :created_at, :datetime
    t.column :updated_at, :datetime
  end

  create_table :replies, force: true do |t|
    t.column :tweet_id, :integer
    t.column :created_at, :datetime
    t.column :updated_at, :datetime
  end
  add_index :replies, [:tweet_id], name: "index_replies_on_tweet_id", using: :btree
end

[Tweet, Reply].each(&:delete_all)

TWEET_COUNT = 5
REPLY_COUNT = 10000

TWEET_COUNT.times do
  tweet = Tweet.create

  replies = REPLY_COUNT.times.map do
    Reply.new(tweet: tweet)
  end
  Reply.import(replies, validate: false)
end

Benchmark.bm do |bench|
  bench.report("COUNT each association") do
    tweets = Tweet.first(TWEET_COUNT)

    tweets.each { |t| t.replies.count }
  end

  bench.report("LEFT JOIN             ") do
    tweets = Tweet.joins('LEFT JOIN replies ON tweets.id = replies.tweet_id').
      select('tweets.*, COUNT(replies.id) AS replies_count').
      group('tweets.id').first(TWEET_COUNT)

    tweets.each { |t| t.replies_count }
  end

  bench.report("preloaded has_count   ") do
    tweets = Tweet.preload(:replies_count).first(TWEET_COUNT)

    tweets.each { |t| t.replies_count }
  end

  bench.report("preloaded has_many    ") do
    tweets = Tweet.preload(:replies).first(TWEET_COUNT)

    tweets.each { |t| t.replies.size }
  end
end
