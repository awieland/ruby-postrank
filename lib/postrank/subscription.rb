module PostRank
  class Subscription
    attr_accessor :id, :feed, :postrank, :filter, :tags, :updated, :created
    
    class << self
      @@base_path = "/myfeeds/subscriptions"
      
      def find(id=:all)
        id = id.to_sym
        request_path = id == (:all || id == :first) ? "#{@@base_path}.js" : "#{@@base_path}/#{id}.js"
        subs = subscriptions_from(Connection.instance.get(request_path))
        id == :all ? subs : subs.first
      end
      alias find_by_id find
    
      def find_by_feed(feed)
        subscriptions_from(Connection.instance.get("#{@@base_path}/feed/#{feed.id}.js")).first
      end
      
      def json_create(o)
        new(:id => o['id'], :feed => o['feed_hash'], :updated => o['updated_at'],
            :created => o['created_at'], :postrank => o['postrank_filter'],
            :filter => o['keyword_filter'], :tags => o['tag_list'])
      end
      
      private
      
      def subscriptions_from(response)
        docs = JSON.parse(response)
        docs = [docs] if docs.respond_to?(:keys)
        docs.map { |doc| Subscription.json_create(doc['subscription']) }
      end      
    end
    
    def initialize(opts={})
      @id = opts[:id]
      @updated = opts[:updated]
      @created = opts[:created]
      @postrank = opts[:postrank]
      @filter = opts[:filter]
      @feed = opts[:feed]

      @tags = []
      @tags << opts[:tags].split(/\s+/) unless opts[:tags].nil?
      @tags.flatten!
    end
    
    def feed
      @feed = Feed.find(@feed) unless @feed.is_a?(Feed)
      @feed
    end
    
    def save
      raise APIException.new("Invalid subscription: #{@errors}") unless valid?
    
      if @id.nil?
        Connection.instance.post("#{@@base_path}.js", sub_data)
      else
        Connection.instance.put("#{@@base_path}/#{@id}.js", sub_data)
      end
    end
  
    def delete
      return if @id.nil?
      Connection.instance.delete("#{@@base_path}/#{@id}.js")
    end

    def valid?
      @errors = []
      if @feed.nil? || feed_hash.length != 32
        @errors << "Invalid feed identifier"
        return false
      end
      true
    end

    def feed_hash
      return @feed.id if @feed.is_a?(Feed)
      @feed
    end
    
    private
    
    def sub_data
      pr = 1.0
      if @postrank
        pr = case (@postrank)
          when Level::ALL then 1.0
          when Level::GOOD then 2.7
          when Level::GREAT then 5.4
          when Level::BEST then 7.6
          else @postrank
        end
      end
      
      data = {:subscription => {
          :feed_hash => feed_hash,
          :postrank_filter => pr,
          :keyword_filter => @filter || "",
          :tag_list => @tags.join(' ')
        }
      }
    end
  end
end
