# frozen_string_literal: true

class User
  include BCrypt

  def initialize(id)
    e = DB.query("SELECT * FROM `tempo_users` WHERE `id` = #{id}").each {}

    @userid = id
    if e.empty?
      @registered = false
      @raw = nil
      @username = nil
      @password = nil
      @email = nil
      @phone = nil
      @fcm_token = nil
    else
      @registered = true
      @raw = e[0]
      @username = @raw['username']
      @username = Discord.user(id).distinct if @username.nil?
      @password = @raw['password']
      @email = @raw['email']
      @phone = @raw['phone']
      @fcm_token = @raw['fcmToken']
    end
  rescue StandardError
    @registered = false
    @raw = nil
    @username = nil
    @password = nil
    @email = nil
    @phone = nil
    @fcm_token = nil
  end

  attr_reader :registered
  alias_method :registered?, :registered
  attr_reader :raw
  attr_reader :username
  attr_reader :email
  attr_reader :phone
  attr_reader :fcm_token
  attr_reader :userid
  alias_method :id, :userid

  def password
    Password.new(DB.query("SELECT `password` FROM `tempo_users` WHERE `id` = #{@userid}").each {}[0]['password'])
  end

  def password_set?
    return false if @password.nil?

    true
  end

  def password=(pass)
    @password = Password.create(pass)
    l = DB.query("UPDATE `tempo_users` SET `password` = '#{@password}' WHERE `tempo_users`.`id` = #{@userid};")
    true
  rescue StandardError
    false
  end

  def username=(name)
    l = DB.query("UPDATE `tempo_users` SET `username` = '#{name}' WHERE `tempo_users`.`id` = #{@userid};")
    @username = name
    true
  rescue StandardError
    false
  end
end
