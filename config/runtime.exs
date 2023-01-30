import Config

config :sftp_api, SFTPAPI.Repo,
  database: System.get_env("DB_NAME", "sftp_api"),
  username: System.get_env("DB_USERNAME", "sftp_api"),
  password: System.get_env("DB_PASSWORD", "secret"),
  hostname: System.get_env("DB_HOST", "db")

config :sftp_api, SFTPAPI.SFTPServer,
  port: System.get_env("APP_PORT", "4000") |> String.to_integer()
