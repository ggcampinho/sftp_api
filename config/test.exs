import Config

config :sftp_api, SFTPAPI.SFTPServer, server: false

config :sftp_api, SFTPAPI.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warn
