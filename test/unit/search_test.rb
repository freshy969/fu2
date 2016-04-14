require 'test_helper'

class SearchTest < ActiveSupport::TestCase

  setup do
    Search.reset_index
  end

  def update_index
    Search.update_index
    wait_for_es
  end

  def wait_for_es
    sleep 1
  end

  test "query" do
    q = Search.query("äbc a:b äfoo \"bar baz\" foo:\"bar baz\"").query
    assert_equal 5, q.size
    assert_equal "äbc", q[0]
    assert_equal ["b", "a"], q[1]
    assert_equal "äfoo", q[2]
    assert_equal "bar baz", q[3]
    assert_equal ["bar baz", "foo"], q[4]
  end

  # test "search query" do
  #   Search.setup_index
  #   u = create_user
  #   p = create_post("test")
  #   wait_for_es
  #   q = Search.query("test").results
  #   assert_equal 3, q[:total_count]
  #   assert_equal 1, q[:objects].size
  #   assert_not_nil q[:objects].first
  # end
  #
  # test "search results pagination" do
  #   u = create_user
  #   p = create_post("test")
  #   wait_for_es
  #   q = Search.query("test", per_page: 1).results
  #   assert_equal 2, q[:result_count]
  #   assert_equal 1, q[:objects].size
  #   assert q[:objects].first.is_a?(Channel)
  #   q = Search.query("test", per_page: 1, offset: 1).results
  #   assert_equal 2, q[:result_count]
  #   assert_equal 1, q[:objects].size
  #   assert q[:objects].first.is_a?(Post)
  # end

  test "update index" do
    Channel.delete_all
    Post.delete_all
    u = create_user
    p = create_post
    Search.reset_index
    update_index
    assert $elastomer.get('/channels-test/_search').body["hits"]["total"] > 0
  end

  test "indexes after create" do
    Search.setup_index
    u = create_user
    p = create_post
    wait_for_es
    assert_equal 1, $elastomer.get('/channels-test/_search').body["hits"]["total"]
    assert_equal 2, $elastomer.get('/posts-test/_search').body["hits"]["total"]
  end

  test "remove from index after destroy" do
    Search.setup_index
    u = create_user
    p = create_post
    c = p.channel
    wait_for_es
    c.posts.each { |post| post.destroy }
    c.destroy
    wait_for_es
    assert_equal 0, $elastomer.get('/channels-test/_search').body["hits"]["total"]
    assert_equal 0, $elastomer.get('/posts-test/_search').body["hits"]["total"]
  end

end
