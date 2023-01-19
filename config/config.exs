import Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:username, :ip, :method]

import_config "#{config_env()}.exs"
