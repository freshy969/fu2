require 'digest/sha1'
require 'bcrypt'

class User < ActiveRecord::Base
  # Virtual attribute for the unencrypted password
  serialize :block_users

  scope :with_login, lambda { |login| where("LOWER(login) = LOWER(:login) and activated_at IS NOT NULL", :login => login) }
  scope :with_api_key, proc { |key| where(api_key: key) }
  scope :active, proc { where("login NOT LIKE '%-disabled'") }

  validates_presence_of     :login, :email
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  # validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login,    :within => 3..40
  validates_length_of       :email,    :within => 3..100
  validates_uniqueness_of   :login, :email, :case_sensitive => false

  before_save :encrypt_password

  before_create :make_activation_code
  before_create :set_display_name
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  # attr_accessible :login, :email, :password, :password_confirmation, :display_name, :stylesheet_id, :markdown, :new_features, :avatar_url

  has_many :posts
  has_many :channel_visits
  has_many :uploads

  has_many :messages
  has_many :unread_messages, lambda { where("status = #{Message::STATUS_UNREAD}") }, :class_name => "Message"

  has_many :faves

  has_many :site_users
  has_many :sites, through: :site_users

  belongs_to :stylesheet

  class << self
    def fubot
      find_by_login("fubot")
    end
  end

  # Activates the user in the database.
  def activate
    @activated = true
    self.activated_at = Time.now.utc
    self.activation_code = nil
    save!
  end

  def can_invite?
    id == 1
  end

  def set_display_name
    self.display_name = login
  end

  def private_channel
    Channel.where("user_id = ? AND title = ? AND default_read = ?", id, "#{login}/Mailbox", false).first
  end

  def active?
    # the existence of an activation code means they have not activated yet
    activation_code.nil?
  end

  # Returns true if the user has just been activated.
  def pending?
    @activated
  end

  def self.all_users
    self.order("LOWER(display_name)").all
  end

  def password
    @password ||= BCrypt::Password.new(password_hash)
  end

  def update_password(oldpw, pw, repeatpw)
    if !authenticated?(oldpw)
      errors.add(:old_password, " does not match the current password")
    end
    if pw != repeatpw
      errors.add(:password_repeat, " does not match the password")
    end
    length = pw.to_s.size
    if length < 4
      errors.add(:password, " is too short (minimum is 4 characters)")
    elsif length > 40
      errors.add(:password, " is too long (maximum is 40 characters)")
    end

    if errors.any?
      @password = nil
    else
      @password = BCrypt::Password.create(pw)
    end
  end

  def password=(pw)
    length = pw.to_s.size
    if length < 4
      errors.add(:password, " is too short (minimum is 4 characters)")
    elsif length > 40
      errors.add(:password, " is too long (maximum is 40 characters)")
    end

    if pw
      @password = BCrypt::Password.create(pw)
    else
      @password = nil
    end
  end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    u = with_login(login).first
    return nil unless u
    u && u.authenticated?(password) ? u : nil
  end

  def authenticated?(password)
    self.password == password
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save # (false)
  end

  def number_unread_messages
    Message.count(:conditions => {:user_id => id, :status => 0})
  end

  def block_user(u)
    self.block_users ||= []
    self.block_users << u.id.to_i
  end

  def enable_api_usage
    if self.api_key.blank?
      self.api_key = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
      save
    end
  end

  def display_name_html
    RenderPipeline.title(display_name)
  end

  def as_json(*args)
    {
      id: id,
      login: login,
      display_name: display_name,
      display_name_html: display_name_html,
      avatar_url: avatar_image_url,
      created_at: created_at
    }
  end

  def new_features
    $redis.sismember("users:new_features", id)
  end

  def new_features=(v)
    if !v
      $redis.srem("users:new_features", id)
    else
      $redis.sadd("users:new_features", id)
    end
  end

  def avatar_image_url(size=32)
    if avatar_url.blank?
      gravatar_id = Digest::MD5.hexdigest(email.downcase)
      "http://gravatar.com/avatar/#{gravatar_id}.png?s=#{size}"
    else
      avatar_url
    end
  end

  def multi_site?
    site_users.count > 1
  end

  def last_active
    ($redis.get("User:#{id}:active") || 0).to_i
  end

  def record_active
    $redis.set("User:#{id}:active", Time.now.to_i)
  end

  protected
    # before filter
    def encrypt_password
      return if password.blank?
      self.password_hash = password
    end

    def password_required?
      !@password.nil? && password_hash.blank?
    end

    def make_activation_code

      self.activation_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
    end

end
