var timestamps = [];

var Timestamp = React.createClass({
  componentDidMount: function() {
    timestamps.push(this);
  },
  componentWillReceiveProps: function() {
    this.lastts = null;
  },
  shouldComponentUpdate: function() {
    if(!this.lastts) return true;
    if(this.lastts != formatTimestamp(this.props.timestamp)) return true;
    return false;
  },
  render: function() {
    if(this.props.timestamp === "") return null;
    this.lastts = formatTimestamp(this.props.timestamp);
    return <span className="ts">{this.lastts}</span>;
  }
});
window.Timestamp = Timestamp;


$(function() {
  window.updateTimestamps = function(timestampE) {
    $.each(timestampE, function(i,e) {
     var t = parseInt($(e).data("timestamp")) * 1000;
     var ts = React.render(<Timestamp timestamp={t} />, e);
     timestamps.push(ts);
   });
  }
  var updateTs = function() {
    $.each(timestamps, function(i, ts) {
      ts.setState({});
    });
  }
  window.setInterval(updateTs, 1000);
});
