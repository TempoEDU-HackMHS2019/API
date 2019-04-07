class ApiController < ApplicationController
  include BCrypt
  include Response

  # No bueno
  def notfound
    json_response(JSON.parse('{"error": "Page not found"}'), 404)
  end

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
      userid = e['id']
    end
    User.new(userid)
  end

  # Create user method
  def create_user
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
      json_response({"error": "You are going too fast"}.as_json, 429)
      return
    end
    if e.empty? # If there are no matches.
      json_response({"error": "Invalid credentials"}.as_json, 401)
      return
    end
    user = User.new(e[0]['id'])

    # Invalid credentials if they don't have a password somehow.
    unless user.password_set?
      json_response({"error": "Invalid credentials"}.as_json, 401)
      return
    end

    # If the password matches
    if user.password == params['password']
      user = User.new(e[0]['id'])
      key = e[0]['auth_token']
      output = {
        "success": true,
        "key": key,
        "user": {
          "id": user.id
        }
      }
      json_response(output.as_json, 200)
    else
      json_response({"error": "Invalid credentials"}.as_json, 401)
      return
    end
  end

  def add_event
    # Check to see if the user is authenticated. Otherwise, bye bye.
    begin
      unless authenticated?(request.headers['Authorization'])
        json_response({"error": "Auth not valid"}.as_json, 401)
        return
      end
    rescue Mysql2::Error
      json_response({"error": "You are going too fast"}.as_json, 429)
      return
    end

    user = auth_user(request.headers['Authorization'])

    # Define parameters we need for later
    name = params['name']
    description = params['description']
    duedate = Time.parse(params['duedate']).to_datetime.to_s.gsub('T', ' ').gsub('+00:00', '')
    parent = params['parent_id'] || 0
    difficulty = params['difficulty']
    type = params['type']

    name = name.gsub('"', '\\"')
    description = description.gsub('"', '\\"')

    re = DB.query("SELECT * FROM `tempo_event` WHERE `name` = \"#{name}\" AND `owner_id` = '#{user.id}'").each {}
    unless re.empty?
      json_response({"error": "An event with this name exists, sorry bucko."}.as_json, 400)
      return
    end

    DB.query("INSERT INTO `tempo_event` (`owner_id`, `name`, `description`, `difficulty`, `due`, `parent_id`, `type`) VALUES ('#{user.id}', \"#{name}\", \"#{description}\", '#{difficulty}', '#{duedate}', '#{parent}', '#{type}')")

    re = DB.query("SELECT * FROM `tempo_event` WHERE `name` = \"#{name}\" AND `owner_id` = '#{user.id}'").each {}[0]

    json_response({"success": true, "id": re['id']}.as_json, 201)
  end

  def get_event
    # Check to see if the user is authenticated. Otherwise, bye bye.
    begin
      unless authenticated?(request.headers['Authorization'])
        json_response({"error": "Auth not valid"}.as_json, 401)
        return
      end
    rescue Mysql2::Error
      json_response({"error": "You are going too fast"}.as_json, 429)
      return
    end

    user = auth_user(request.headers['Authorization'])

    # Define parameters we need for later
    id = params['id']

    event = DB.query("SELECT * FROM `tempo_event` WHERE `id` = '#{id}' AND `owner_id` = '#{user.id}'").each {}
    if event.empty?
      json_response({"error": "no events exist with this id"}.as_json, 400)
      return
    end

    event = event[0]

    output = {
      "id": event['id'],
      "name": event['name'],
      "description": event['description'],
      "duedate": event['due'],
      "parent": event['parent_id'],
      "difficulty": event['difficulty'],
      "type": event['type']
    }

    json_response(output.as_json, 200)
  end

  def get_events
    # Check to see if the user is authenticated. Otherwise, bye bye.
    begin
      unless authenticated?(request.headers['Authorization'])
        json_response({"error": "Auth not valid"}.as_json, 401)
        return
      end
    rescue Mysql2::Error
      json_response({"error": "You are going too fast"}.as_json, 429)
      return
    end

    user = auth_user(request.headers['Authorization'])

    event = DB.query("SELECT * FROM `tempo_event` WHERE `owner_id` = '#{user.id}'").each {}

    output = []

    event.each do |ev|
      f = {
        "id" => ev['id'].to_i,
        "name" => ev['name'],
        "description" => ev['description'],
        "duedate" => ev['due'],
        "parent" => ev['parent_id'].to_i,
        "difficulty" => ev['difficulty'].to_i,
        "type" => ev['type'].to_i
      }
      output.push f
    end

    json_response(output.as_json, 200)
  end

  def delete_event
    # Check to see if the user is authenticated. Otherwise, bye bye.
    begin
      unless authenticated?(request.headers['Authorization'])
        json_response({"error": "Auth not valid"}.as_json, 401)
        return
      end
    rescue Mysql2::Error
      json_response({"error": "You are going too fast"}.as_json, 429)
      return
    end

    user = auth_user(request.headers['Authorization'])

    # Define parameters we need for later
    id = params['id']

    event = DB.query("SELECT * FROM `tempo_event` WHERE `id` = '#{id}' AND `owner_id` = '#{user.id}'").each {}
    if event.empty?
      json_response({"error": "no events exist with this id"}.as_json, 400)
      return
    end

    event = event[0]

    event = DB.query("DELETE FROM `tempo_event` WHERE `tempo_event`.`id` = #{event['id']}")

    json_response({"success": true}.as_json, 200)
  end

  def profile
    # Check to see if the user is authenticated. Otherwise, bye bye.
    begin
      unless authenticated?(request.headers['Authorization'])
        json_response({"error": "Auth not valid"}.as_json, 401)
        return
      end
    rescue Mysql2::Error
      json_response({"error": "You are going too fast"}.as_json, 429)
      return
    end

    user = auth_user(request.headers['Authorization'])

    output = {
      "id" => user.id,
      "username" => user.username
    }

    json_response(output.as_json, 200)
  end
end
