DB = Mysql2::Client.new(
  host: ENV["DBIP"],
  username: ENV["DBUSERNAME"],
  password: ENV["DBPASSWORD"],
  database: ENV["DBDB"],
  reconnect: true,
  encoding: 'utf8mb4'
)
