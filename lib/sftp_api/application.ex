defmodule SFTPAPI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias SFTPAPI.SFTPServer

  @impl true
  def start(_type, _args) do
    children = [
      {SFTPServer, []}
    ]

    opts = [strategy: :one_for_one, name: SFTPAPI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
