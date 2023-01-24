import Config

config :sftp_api,
  ecto_repos: [SFTPAPI.Repo]

config :sftp_api, SFTPAPI.Repo,
  migration_primary_key: [type: :binary_id],
  migration_foreign_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:username, :ip, :method]

import_config "#{config_env()}.exs"
