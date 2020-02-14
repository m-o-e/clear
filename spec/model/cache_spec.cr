require "../spec_helper"
require "./cache_schema"

# Monkey patch of QueryCache
# For adding statistics
# during spec
class Clear::Model::QueryCache
  class_getter cache_hitted : Int32 = 0

  def hit(relation_name, relation_value, klass : T.class) : Array(T) forall T
    @@cache_hitted += 1
    previous_def
  end

  def self.reset_counter
    @@cache_hitted = 0
  end
end

module CacheSpec
  def self.reinit
    reinit_example_models

    User.create! id: 101, first_name: "User 1"
    User.create! id: 102, first_name: "User 2"

    Category.create! id: 201, name: "Test"
    Category.create! id: 202, name: "Test 2"

    Post.create! id: 301, title: "post 301", published: true, user_id: 101, category_id: 201, content: "Lorem ipsum"
    Post.create! id: 302, title: "post 302", published: true, user_id: 102, category_id: 201, content: "Lorem ipsum"
    Post.create! id: 303, title: "post 303", published: true, user_id: 102, category_id: 202, content: "Lorem ipsum"
    Post.create! id: 304, title: "post 304", published: true, user_id: 101, category_id: 202, content: "Lorem ipsum"
  end

  describe "Clear::Model" do
    context "cache system" do
      it "manage has_many relations" do
        temporary do
          reinit
          Clear::Model::QueryCache.reset_counter
          # relations has_many
          User.query.first!.posts.count.should eq(2)
          User.query.with_posts(&.published.with_category).each do |user|
            Clear::Model::QueryCache.reset_counter
            user.posts.count.should eq(2)
            Clear::Model::QueryCache.cache_hitted.should eq(1)
          end
        end
      end

      it "can be chained" do
        temporary do
          reinit
          Clear::Model::QueryCache.reset_counter
          User.query.with_posts(&.with_category).each do |user|
            user.posts.each do |p|
              case p.id
              when 301, 302
                (p.category.not_nil!.id == 201).should eq(true)
              when 303, 304
                (p.category.not_nil!.id == 202).should eq(true)
              end
            end
          end
        end
      end

      it "can be called in chain on the through relations" do
        temporary do
          reinit
          # Relation belongs_to
          Clear::Model::QueryCache.reset_counter
          Post.query.with_user.each do |post|
            post.user.not_nil!
          end
          Clear::Model::QueryCache.cache_hitted.should eq(4) # Number of posts

          Category.query.with_users { |q| q.order_by("model_users.id", "asc") }.order_by("id", "asc").each do |c|
            c.users.each do |user|
              c.id.not_nil!
              user.id.not_nil!
            end
          end
        end
      end

    end
  end
end
