defmodule SFTPAPI.Repo do
  @moduledoc """
  Default Repo for Ecto
  """

  use Ecto.Repo,
    otp_app: :sftp_api,
    adapter: Ecto.Adapters.Postgres,
    show_sensitive_data_on_connection_error: true
end
