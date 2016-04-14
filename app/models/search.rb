class Search

  class << self

    def query(query, options={})
      new(query, options)
    end

    def index(name)
      $elastomer.index index_name(name)
    end

    def docs(name)
      $elastomer.docs index_name(name)
    end

    def more_like_this(name, field, type, id)
      $elastomer.docs(index_name(name)).more_like_this({from: 0, size: 100}, mlt_fields: field, min_term_freq: 1, type: type, id: id)
    end

    def update_index
      setup_index

      if ENV["INDEX"].blank? || ENV["INDEX"] == "channels"
        count = Channel.count
        Channel.includes(:user).find_each(batch_size: 2000).with_index { |c,i| index_doc("channels", c, i, count) }
      end
      if ENV["INDEX"].blank? || ENV["INDEX"] == "posts"
        count = Post.count
        Post.includes(:user, :channel, :faves => [:user]).find_each(batch_size: 2000).with_index { |p,i| index_doc("posts", p, i, count) }
      end
    end

    def build_index(name, klass)
      i = index(name)
      i.create(klass.index_definition) if !i.exists?
    end

    def index_name(name)
      "#{name}-#{Rails.env}"
    end

    def reset_index
      %w(channels posts).each do |name|
        i = index(name)
        i.delete if i.exists? && (ENV["INDEX"].blank? || ENV["INDEX"] == name)
      end
    end

    def setup_index
      build_index "channels", Channel if ENV["INDEX"].blank? || ENV["INDEX"] == "channels"
      build_index "posts", Post if ENV["INDEX"].blank? || ENV["INDEX"] == "posts"
    end

    def index_doc(name, obj, n, count)
      data = obj.to_indexed_json
      return if data.keys.size < 1
      rt = 0
      begin
        d = docs(name)
        Rails.logger.info "+#{index_name name}: #{data[:id]} (#{n+1}/#{count})"
        d.index(data)
      rescue Elastomer::Client::TimeoutError => e
        rt += 1
        if rt < 5
          Rails.logger.info "retry +#{index_name name}: #{data[:id]} (#{n+1}/#{count})"
          retry
        else
          raise e
        end
      end
    end

    def remove_doc(name, id, type, n, count)
      d = docs(name)
      Rails.logger.info "-#{index_name name}: #{id} (#{n+1}/#{count})"
      d.delete(id: id, type: type)
    end

    def update(name, id)
      Resque.enqueue(IndexJob, :update, name, id)
    end

    def remove(name, id)
      Resque.enqueue(IndexJob, :remove, name, id)
    end

  end

  attr_accessor :query

  QUERIES = [ChannelsQuery, PostsQuery]

  def initialize(query, options={})
    @query = parse_query query
    @options = options
    @results = nil
    @offset = options.fetch(:offset, 0)
    @per_page = options.fetch(:per_page, 25)
    @options[:per_page] = @per_page
  end

  def parse_query(query)
    s = query.to_s.strip
    q = []
    scanner = StringScanner.new(s)
    while !scanner.eos?
      if scanner.scan /((\S+):)?\"([^\"]+)\"(\s+|$)/
        if scanner[2]
          q << [scanner[3], scanner[2]]
        else
          q << scanner[3]
        end
      elsif scanner.scan /((\S+):)?(\+?\S+)(\s+|$)/
        if scanner[2]
          q << [scanner[3], scanner[2]]
        else
          q << scanner[3]
        end
      else
        if q.last.is_a?(String)
          q.last << (scanner.scan_until(/ |$/) || '')
        elsif q.last.is_a?(Array)
          q.last[0] << (scanner.scan_until(/ |$/) || '')
        elsif q.size == 0
          q << scanner.getch
        else
          Rails.logger.info "query parser discarding #{scanner.getch} (#{query})"
        end
      end
    end
    q
  end

  def results
    return @results if @results
    offset = @offset
    @results = {
      total_count: 0,
      result_count: 0,
      offset: offset,
      objects: [],
      scores: []
    }
    n = 0
    QUERIES.each do |query|
      next if @options[:type] && @options[:type] != query.index
      r = query.new(@query, @options.merge(offset: offset)).results
      @results[:total_count] += r[:total_count]
      @results[:result_count] += r[:result_count]
      i = 0
      while i < r[:objects].size && n + i < @per_page
        @results[:objects] << r[:objects][i]
        @results[:scores] << r[:scores][i]
        i += 1
      end
      n += i
    end
    @results
  end


end
