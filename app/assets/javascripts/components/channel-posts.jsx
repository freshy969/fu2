// var React = require('react');
// var LoadingIndicator = require("./loading-indicator");

var ChannelPostsData = {
  url: "/api/channels/{id}/posts.json",
  result: {
    posts: ["post"],
    channel: "channel"
  },
  view: "channel-$ID-post",
  subscribe: [
    "post_create",
    "post_fave",
    "post_unfave",
    "event_create"
  ]
};



var ChannelPosts = React.createClass({
  getInitialState: function() {
    return {posts: [], events: [], channel: {}, view: {}, anchor: "", highlight: -1};
  },
  componentDidMount: function() {
    if(this.props.channelId > 0) {
      Data.subscribe("channel-"+this.props.channelId+"-post", this, 0, {callback: this.updatedPosts});
      Data.subscribe("channel-"+this.props.channelId+"-event", this, 0, {callback: this.updatedEvents});
      Data.subscribe("channel", this, this.props.channelId, {callback: this.updatedChannel});
      Data.fetch(ChannelPostsData, this.props.channelId, {}, this.loadNew);
    }

    var self = this;
    this.keydownCallback = $(document).on("keydown", function(e) {
      if(!self.isMounted()) return;
      if(e.target != $("body").get(0)) return;
      var key = String.fromCharCode(e.keyCode);
      if(key == "U" && e.ctrlKey && !e.metaKey && !e.shiftKey && !e.altKey) {
        self.setState({highlight: 0});
        self.updateAnchor();
        e.preventDefault();
      }
      if(key == "D" && e.ctrlKey && !e.metaKey && !e.shiftKey && !e.altKey) {
        self.setState({highlight: self.state.posts.length-1});
        self.updateAnchor();
        e.preventDefault();
      }
      if(e.ctrlKey || e.metaKey || e.shiftKey || e.altKey) return;
      if(key == "J") {
        if(self.state.highlight < self.state.posts.length-1) {
          self.setState({highlight: self.state.highlight+1});
          self.updateAnchor();
        }
        e.preventDefault();
      }
      if(key == "K") {
        if(self.state.highlight > 0) {
          self.setState({highlight: self.state.highlight-1});
          self.updateAnchor();
        }
        e.preventDefault();
      }
      if(key == "M") {
        self.loadMore();
        e.preventDefault();
      }
      if(key == "A") {
        self.loadAll();
        e.preventDefault();
      }
      if(key == "R") {
        if(self.state.highlight >= 0 && $("textarea.comment-box").val().length == 0) {
          var post = self.state.posts[self.state.highlight];
          ChannelPosts.replyMessage(post);
          e.preventDefault();
        }
      }
      if(key == "C") {
        var o = $("textarea.comment-box").select().offset();
        if(o) $(window).scrollTop(o.top - 150);
        e.preventDefault();
      }
    });
  },
  componentWillUnmount: function() {
    Data.unsubscribe(this, ChannelPostsData.subscribe);
    $(document).off("keydown", this.keydownCallback);
  },
  selectPost: function(post, highlight, noscroll) {
    if(!highlight) highlight = this.state.highlight;
    var h = "#post-"+post.id;
    if(document.location.hash != h) {
      history.pushState(null, null, location.pathname+h);
      if(this.isMounted() && this.state.anchor != h) {
        this.setState({anchor: h, highlight: highlight});
      }
    }
    var post = $(this.getDOMNode()).find(".post-"+post.id);
    if(!noscroll && post.length > 0) {
      var o = post.offset();
      $(window).scrollTop(o.top - 150);
      return true;
    }
    return false;
  },
  updateAnchor: function() {
    if(this.state.highlight >= 0) {
      var post = this.state.posts[this.state.highlight];
      if(post) {
        return this.selectPost(post);
      }
    }
    return false;
  },
  updatedPosts: function(objects, view) {
    highlight = this.state.highlight;
    var jump = false;
    if(highlight == -1) {
      for(var p in objects) {
        var post = objects[p];
        if((this.state.anchor.length > 0 && post.id == parseInt(this.state.anchor.replace(/#?post[-_]/, '')))) {
          highlight = parseInt(p);
          jump = true;
          break;
        }
      }
    }
    if(this.state.posts.length == 0 && this.state.anchor !== "") {
      var anchorPostId =  parseInt(this.state.anchor.replace(/#?post[-_]/, ''));
      var found = false;
      for(var p in objects) {
        var post = objects[p];
        if(post.id == anchorPostId) {
          found = true;
          break;
        }
      }
      if(!found) {
        Data.fetch(ChannelPostsData, this.props.channelId, {last_id: anchorPostId - 1, limit: view.count});
      }
    }
    var items = objects.concat(this.state.events).sort(function(a,b) { return new Date(a.created_at) - new Date(b.created_at); });
    this.setState({posts: objects, items: items, view: view, highlight: highlight, jump: true});
  },
  updatedEvents: function(objects, view) {
    var items = this.state.posts.concat(objects).sort(function(a,b) { return new Date(a.created_at) - new Date(b.created_at); });
    this.setState({events: objects, items: items});
  },
  updatedChannel: function(objects, view) {
    if(objects.length > 0 && (!this.state.channel.id || objects[0].id == this.state.channel.id)) {
      document.title = objects[0].title+" | Red Cursor";
      this.setState({channel: objects[0]});
    }
  },
  loadMore: function(e) {
    Data.fetch(ChannelPostsData, this.props.channelId, {first_id: this.state.view.start_id});
    if(e)
      e.preventDefault();
  },
  loadAll: function(e) {
    Data.fetch(ChannelPostsData, this.props.channelId, {last_id: 0, limit: this.state.view.count});
    if(e)
      e.preventDefault();
  },
  loadNew: function(e) {
    if(!this.isMounted()) return;
    Data.fetch(ChannelPostsData, this.props.channelId, {last_id: this.state.view.last_read_id, last_update: this.state.view.last_update});
    if(e)
      e.preventDefault();
  },
  componentDidUpdate: function() {
    if(this.isMounted()) {
      if(this.state.jump && this.updateAnchor())
        this.setState({jump: false});
      var self = this;
      twttr.ready(function() {
        twttr.widgets.load(self.getDOMNode());
      });
    }
  },
  bodyClick: function(e) {
    var post = $(e.target).parents(".channel-post");
    var id = parseInt(post.get(0).className.replace(/[^0-9]+/, ''));
    var n = 0;
    for(var i in this.state.posts) {
      var p = this.state.posts[i];
      if(p.id == id) {
        this.selectPost(p, n, true);
        break;
      }
      n++;
    }
  },
  render: function () {
    var anchorPostId = this.state.anchor == "" ? 0 : parseInt(this.state.anchor.replace(/#?post[-_]/, ''))
    if(this.props.channelId > 0 && (this.state.posts.length < 1 || !this.state.channel.id)) return <LoadingIndicator />;
    if(this.props.channelId > 0) {
      var channelId = this.props.channelId;
      var highlight = this.state.highlight;
      var pi = 0;
      var self = this;
      var posts = this.state.items.map(function(post, i) {
        var user = Data.get("user", post.user_id);
        if(post.type.match(/-event$/)) {
          return <ChannelEvent key={"event-"+post.id} id={post.id} event={post} user={user} />;
        } else {
          pi++;
          return <ChannelPost key={"post-"+post.id} id={post.id} highlight={pi - 1 == highlight} channelId={channelId} user={user} post={post} editable={user.id == Data.user_id} bodyClick={self.bodyClick} />;
        }
      });
      var commentbox = <div>
        <a name="comments"></a>
        <h3 className="channel-response-title">Comment</h3>
        <div className="channel-response">
          <CommentBox channelId={channelId} />
        </div>
      </div>;
    }
    return <div>
      <ChannelPostsHeader channelId={this.props.channelId} channel={this.state.channel} channelPosts={this} />
      <ViewLoader callback={this.loadMore} callbackAll={this.loadAll} visible={this.state.posts.length} count={this.state.view ? this.state.view.count : 0} octicon={"chevron-up"} message={"older posts"} messageAll={"Show all"} />
      {posts}
      {commentbox}
    </div>;
  }
});

ChannelPosts.quote = function(text) {
  return text.split("\n\n").map(function(l,i) { return "> "+l; }).join("\n\n")+"\n\n";
}

ChannelPosts.replyMessage = function(post) {
  $(".comment-box-form textarea").val(ChannelPosts.quote(post.body)).select();
  $(window).scrollTop($(".comment-box-form textarea").offset().top - 150)
}

// module.exports = ChannelPosts;
window.ChannelPosts = ChannelPosts;