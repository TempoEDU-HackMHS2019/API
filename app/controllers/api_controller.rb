class ApiController < ApplicationController
  include BCrypt
  include Response

  # Method to see if user is authenticated
  def authenticated?(key)
    return false if key == '' || key.nil?

    results = []
    query = DB.query("SELECT * FROM `tempo_users` WHERE `auth_token` = '#{key}'")
    query.each do |e|
      results.push e
    end
    results.length.positive?
  end

  # Method to find the authenticated user
  def auth_user(key)
    query = DB.query("SELECT * FROM `tempo_users` WHERE `auth_token` = '#{key}'")
    results = []
    userid = 0
    query.each do |e|
      results.push e
      userid = e['userid']
    end
    userid
  end

  # Create user method
  def create_user
    form_authenticity_token = nil

    # Define variables from the request
    username = params['username']
    password = params['password']
    email = params['email']
    phone = params['phone']

    # Check to see if email exists
    emails = DB.query("SELECT * FROM `tempo_users` WHERE `email` = '#{email}'").each {}
    unless emails.empty?
      json_response({"status": "error", "reason": "email already exists" }.as_json, 400)
      return
    end

    # Same with username
    emails = DB.query("SELECT * FROM `tempo_users` WHERE `username` = '#{username}'").each {}
    unless emails.empty?
      json_response({"status": "error", "reason": "username already exists" }.as_json, 400)
      return
    end

    # Hash the password, we're not insecure.
    hashed_password = Password.create(password)

    # Now we add stuff to database and return a nice API key for the Apps to use
    o = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
    key = (0...50).map { o[rand(o.length)] }.join

    DB.query("INSERT INTO `tempo_users` (`email`, `phone`, `password`, `username`, `auth_token`) VALUES ('#{email}', '#{phone}', '#{hashed_password}', '#{username}', '#{key}')")

    json_response({"status": "success", "key": key }.as_json, 201)
  end

  # Login user method, returns key for the app
  def login
    # Parameters we store for later
    password = params['password']
    email = params['email']

    # Check if email exists, if it doesn't, tell the user they're doing it wrong, not how.
    begin
      e = DB.query("SELECT * FROM `tempo_users` WHERE `email` = '#{email}'").each {}
    rescue Mysql2::Error
      # If the user spams, don't blame us, blame them.
      json_response(JSON.parse('{"error": "You are going too fast"}'), 429)
      return
    end
    if e.empty? # If there are no matches.
      json_response(JSON.parse('{"error": "Invalid credentials"}'), 401)
      return
    end
    user = User.new(e[0]['id'])

    unless user.password_set?
      json_response(JSON.parse('{"error": "Invalid credentials"}'), 401)
      return
    end

    if user.password == params['password']
      key = ''
      if e[0]['auth_token'] == '' || e[0]['auth_token'].nil?
        o = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten
        string = (0...50).map { o[rand(o.length)] }.join
        key = string
        DB.query("UPDATE `tempo_users` SET `auth_token` = '#{string}' WHERE `id` = #{e[0]['userid']}")
      else
        key = e[0]['auth_token']
      end
      output = {
        "success": true,
        "key": key
      }
      json_response(output.as_json, 200)
    else
      json_response(JSON.parse('{"error": "Invalid credentials"}'), 401)
      return
    end
  end
end
