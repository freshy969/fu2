module Views
  class ChannelPosts < ListView

    attrs :current_user, :channel, :last_read_id, :first_id, :last_id, :limit, :last_update, :tag

    fetches :posts, proc {
      if tag
        p = ChannelTag.posts(site, tag)
        if first_id
          p = p.before_id(first_id)
        elsif last_id
          p = p.since_id(last_id)
        end
      else
        p = if first_id
          Post.before(channel, first_id)
        elsif last_id
          Post.since(channel, last_id)
        end
      end

      if p
        p = p.includes(:user, :faves)
        if limit
          p = p.order("id desc").limit(limit.to_i).reverse
        else
          p = p.order("id")
        end
      end

      posts = p || channel && channel.show_posts(current_user, last_read_id)
      posts = [] if !posts
      posts.each do |p|
        p.channel = channel
        p.read = !(last_read_id && p.id > last_read_id)
      end
      posts
    }
    fetches :updated_posts, proc { last_update ? Post.updated_since(channel, last_update) : [] }
    fetches :last_update, proc { (posts.map(&:created_at) + posts.map(&:updated_at) + updated_posts.map(&:updated_at)).map(&:utc).max.to_i }, [:posts, :updated_posts]
    fetches :count, proc {
      if tag
        ChannelTag.posts(site, tag).count
      else
        channel.posts.count
      end
    }
    fetches :start_id, proc { posts.select { |p| p.is_a?(Post) }.map(&:id).min }, [:posts]
    fetches :end_id, proc { posts.select { |p| p.is_a?(Post) }.map(&:id).max }, [:posts]

  end
end
