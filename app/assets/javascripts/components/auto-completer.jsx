var AutoCompleterResult = React.createClass({
  render: function() {
    var className = "result "+ (this.props.highlight ? "highlight" : "");
    var title = this.props.value.login ? this.props.value.login :  this.props.value.title ? this.props.value.title : this.props.value;
    var image = this.props.value.image ? this.props.value.image  : null;
    var description = this.props.value.description ? <span className="description">{this.props.value.description}</span> : null;
    return <li className={className} onClick={this.props.clickCallback} data-value={title}><img src={image} />{title}{description}</li>;
  }
});

var AutoCompleter = React.createClass({
  componentDidMount: function() {
    if(this.props.mountCallback) {
      this.props.mountCallback(this);
    }
  },
  render: function() {
    var input = this.props.input;
    var selection = this.props.selection;
    var imageUrl = this.props.imageUrl;
    var clickCallback = this.props.clickCallback;
    var n = 0;
    var results = this.props.objects.map(function(r, i) {
      var s = r;
      if(r.login) {
        s = r.login;
        r.image = r.avatar_url;
      } else if(r.title) {
        s = r.title;
      }
      var highlight = selection == i;
      return <AutoCompleterResult key={s} value={r} highlight={highlight} imageUrl={imageUrl} clickCallback={clickCallback} />;
    })
    return <ul className="autocompleter">
      {results}
    </ul>;
  }
});

// module.exports = AutoCompleter;
window.AutoCompleter = AutoCompleter;
