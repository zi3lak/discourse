# frozen_string_literal: true

require "rails_helper"

describe HasHintedAssociations do
  # Assertion for checking the number of queries executed within the &block
  # https://gist.github.com/pch/7943475
  def assert_queries(num = 1, &block)
    queries  = []
    callback = lambda { |name, start, finish, id, payload|
      queries << payload[:sql] if payload[:sql] =~ /^SELECT|UPDATE|INSERT/
    }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
  ensure
    assert_equal num, queries.size, "#{queries.size} instead of #{num} queries were executed.#{queries.size == 0 ? '' : "\nQueries:\n#{queries.join("\n")}"}"
  end

  before do
    DB.exec("create temporary table fake_posts(id SERIAL primary key, _hinted_associations text[] not null default '{}')")
    DB.exec("create temporary table fake_polls(id SERIAL primary key, fake_post_id integer not null, data text)")
    DB.exec("create temporary table fake_post_notices(id SERIAL primary key, fake_post_id integer not null, data text)")
    DB.exec("create temporary table fake_surveys(id SERIAL primary key, fake_post_id integer not null, data text)")

    class FakePost < ActiveRecord::Base
      include HasHintedAssociations

      # TODO: A plugin API for these
      has_many_hinted :fake_polls
      has_many_hinted :fake_post_notices
      has_many_hinted :fake_surveys
    end

    class FakePoll < ActiveRecord::Base
      belongs_to :post
    end

    class FakePostNotice < ActiveRecord::Base
      belongs_to :post
    end

    class FakeSurvey < ActiveRecord::Base
      belongs_to :post
    end
  end

  after do
    Object.send(:remove_const, :FakePost)
    Object.send(:remove_const, :FakePoll)
    Object.send(:remove_const, :FakePostNotice)
    Object.send(:remove_const, :FakeSurvey)
  end

  it "sets the hint automatically" do
    post = FakePost.create!
    post.fake_polls.new(data: "poll1")
    post.fake_polls.new(data: "poll2")
    post.save!

    expect(post._hinted_associations).to eq(["fake_polls"])

    expect(FakePost.find(post.id).fake_polls.map(&:data)).to contain_exactly(
      "poll1", "poll2"
    )

    post.fake_polls.destroy_all
    expect(post._hinted_associations).to eq([])
  end

  it "will only preload associations which are hinted" do
    p1 = FakePost.create!(fake_polls: [FakePoll.new]).id
    p2 = FakePost.create!(fake_post_notices: [FakePostNotice.new]).id
    p3 = FakePost.create!(fake_surveys: [FakeSurvey.new]).id
    p4 = FakePost.create!(fake_polls: [FakePoll.new], fake_post_notices: [FakePostNotice.new], fake_surveys: [FakeSurvey.new]).id
    p5 = FakePost.create!().id
    p6 = FakePost.create!().id

    to_preload = [:fake_polls, :fake_post_notices, :fake_surveys]

    assert_queries(1) do # These posts have no hinted associations
      FakePost.where(id: [p5, p6]).preload(*to_preload).to_a
      # SELECT "fake_posts".* FROM "fake_posts" WHERE "fake_posts"."id" IN (5, 6)
    end

    assert_queries(2) do # One post has a poll
      FakePost.where(id: [p1, p5, p6]).preload(*to_preload).to_a
      # SELECT "fake_posts".* FROM "fake_posts" WHERE "fake_posts"."id" IN (1, 5, 6)
      # SELECT "fake_polls".* FROM "fake_polls" WHERE "fake_polls"."fake_post_id" = 1
    end

    assert_queries(3) do # One post has a poll, one has a survey
      FakePost.where(id: [p1, p2, p5, p6]).preload(*to_preload).to_a
      # SELECT "fake_posts".* FROM "fake_posts" WHERE "fake_posts"."id" IN (1, 2, 5, 6)
      # SELECT "fake_polls".* FROM "fake_polls" WHERE "fake_polls"."fake_post_id" = 1
      # SELECT "fake_post_notices".* FROM "fake_post_notices" WHERE "fake_post_notices"."fake_post_id" = 2
    end

    assert_queries(4) do # One post has a poll, one has a survey, one has a post_notice
      FakePost.where(id: [p1, p2, p3, p5, p6]).preload(*to_preload).to_a
      # SELECT "fake_posts".* FROM "fake_posts" WHERE "fake_posts"."id" IN (1, 2, 3, 5, 6)
      # SELECT "fake_polls".* FROM "fake_polls" WHERE "fake_polls"."fake_post_id" = 1
      # SELECT "fake_post_notices".* FROM "fake_post_notices" WHERE "fake_post_notices"."fake_post_id" = 2
      # SELECT "fake_surveys".* FROM "fake_surveys" WHERE "fake_surveys"."fake_post_id" = 3
    end

    assert_queries(4) do # One post has all three relations
      FakePost.where(id: [p4]).preload(*to_preload).to_a
      # SELECT "fake_posts".* FROM "fake_posts" WHERE "fake_posts"."id" = 4
      # SELECT "fake_polls".* FROM "fake_polls" WHERE "fake_polls"."fake_post_id" = 4
      # SELECT "fake_post_notices".* FROM "fake_post_notices" WHERE "fake_post_notices"."fake_post_id" = 4
      # SELECT "fake_surveys".* FROM "fake_surveys" WHERE "fake_surveys"."fake_post_id" = 4
    end
  end

end
