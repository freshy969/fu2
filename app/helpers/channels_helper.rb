module ChannelsHelper
  
  def format_body(post)
    text = simple_format(post.body)
    if text.length < 64000
      text = auto_link(text)
    end
    text
  end
  
  def user_link(user)
    return "" unless user
    link_to h(user.login), user_path(user), :style => user.display_color
  end
  
  def user_name(user)
    "&lt;".html_safe + user_link(user) + "&gt;".html_safe
  end
  
end
