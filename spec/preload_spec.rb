require "spec_helper"

describe "#preload" do
  describe "builtin associations" do
    let(:replies_count) { 3 }
    let!(:tweet) { FactoryGirl.create(:tweet) }
    before do
      replies_count.times do
        FactoryGirl.create(:reply, tweet: tweet)
      end
    end

    context "given has_many association" do
      it "works as usual" do
        tweet = Tweet.preload(:replies).first
        expect(tweet.replies.count).to eq(replies_count)
      end
    end

    context "given belongs_to association" do
      let!(:reply) { FactoryGirl.create(:reply, tweet: tweet) }

      it "works as usual" do
        preloaded_reply = Reply.preload(:tweet).find(reply.id)
        expect(preloaded_reply.tweet).to eq(tweet)
      end
    end
  end

  describe "count_preloadable association" do
    let(:tweets_count) { 3 }
    let(:tweets) do
      tweets_count.times.map do
        FactoryGirl.create(:tweet)
      end
    end

    before do
      tweets.each_with_index do |tweet, index|
        index.times do
          FactoryGirl.create(:reply, tweet: tweet)
        end
      end
    end

    it "does not execute N+1 queries by preload" do
      expect_query_counts(1 + tweets_count) { Tweet.all.map(&:replies_count) }
      expect_query_counts(2) { Tweet.all.preload(:replies_count).map(&:replies_count) }
    end

    it "counts properly" do
      expected = Tweet.all.map { |t| t.replies.count }
      expect(Tweet.all.map(&:replies_count)).to eq(expected)
      expect(Tweet.all.preload(:replies_count).map(&:replies_count)).to eq(expected)
    end
  end
end