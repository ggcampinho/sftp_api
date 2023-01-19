import Config

config :sftp_api, SFTPAPI.SFTPServer,
  port: System.get_env("APP_PORT", "4000") |> String.to_integer()
