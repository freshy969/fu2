var ChannelPostHeader = React.createClass({
  edit: function(e) {
    e.preventDefault();
    this.props.channelPost.setState({edit: !this.props.channelPost.state.edit});
  },
  deletePost: function(e) {
    var type = this.props.post.type;
    var id = this.props.id;
    e.preventDefault();
    if(!confirm("Are you sure that you want to delete this post?")) return;
    Data.action("delete", "post", [this.props.channelId, id], {}, {error: function() {
      console.log("Failed to delete post...");
    }, success: function(data) {
      Data.remove(type, id);
      Data.notify([type]);
    }});
  },
  reply: function(e) {
    this.props.channelPost.props.posts.replyMessage(this.props.post);
    e.preventDefault();
  },
  unread: function(e) {
    e.preventDefault();
  },
  render: function() {
    var postLink = Data.url_root + "/channels/"+this.props.channelId+"#post-"+this.props.id;
    var postDeleteLink = this.props.editable ? <a href="#" className="post-delete" onClick={this.deletePost}><span className="octicon octicon-trashcan"></span></a> : null;
    var postEditLink = this.props.editable ? <a href="#" className="post-edit" onClick={this.edit}><span className="octicon octicon-pencil"></span></a> : null;
    var postUnreadLink = <a href="#" className="post-unread" onClick={this.unread}><span className="octicon octicon-eye"></span></a>;
    var postReplyLink = <a href="#" className="post-reply" onClick={this.reply}><span className="octicon octicon-mail-reply"></span></a>;
    var favers = [];
    for(var i in this.props.post.faves) {
      var fave = this.props.post.faves[i];
      favers.push([Data.get("user", fave.user_id).login, fave.emoji]);
    }
    return <div className="channel-post-header">
      <UserLink user={this.props.user} />
      <div className="right">
        <FaveCounter faves={favers} postId={this.props.id} user={this.props.user.login}  />
        {postDeleteLink}
        {postEditLink}
        {postUnreadLink}
        {postReplyLink}
        <a href={postLink} className="timestamp">
          <Timestamp timestamp={this.props.post.created_at} />
        </a>
      </div>
    </div>;
  }
})

var ChannelPost = React.createClass({
  getInitialState: function() {
    return {edit: false};
  },
  cancelEdit: function(e) {
    this.setState({edit: false});
    if(e) e.preventDefault();
  },
  render: function() {
    var body = {__html: this.props.post.html_body};
    var className = "channel-post post-"+this.props.post.id;
    var name = "post-"+this.props.post.id;
    if(this.props.post.read) className += " read";
    if(this.props.highlight) className += " highlight";
    var content = <div className="body" onClick={this.props.bodyClick} dangerouslySetInnerHTML={body}></div>;
    if(this.props.editable && this.state.edit) {
      var comments = <CommentBox postId={this.props.post.id} initialText={this.props.post.body} postId={this.props.id} channelId={this.props.channelId} callback={this.cancelEdit} cancelCallback={this.cancelEdit} />;
      var edit = <div className="channel-response channel-edit">{comments}</div>;
    }
    return <div className={className}>
      <a name={name} />
      <ChannelPostHeader id={this.props.id} channelId={this.props.channelId} user={this.props.user} post={this.props.post} channelPost={this} editable={this.props.editable} />
      {content}
      {edit}
    </div>;
  }
});

// module.exports = ChannelPost;
window.ChannelPost = ChannelPost;
