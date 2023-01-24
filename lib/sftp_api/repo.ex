defmodule SFTPAPI.Repo do
  @moduledoc """
  Default Repo for Ecto
  """

  use Ecto.Repo,
    otp_app: :sftp_api,
    adapter: Ecto.Adapters.Postgres
end
