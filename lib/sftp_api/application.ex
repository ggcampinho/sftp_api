defmodule SFTPAPI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias SFTPAPI.SFTPServer
  alias SFTPAPI.ActionHandler

  @impl true
  def start(_type, _args) do
    {:ok, _ref, _port} = SFTPServer.start_daemon({ActionHandler, []})
    start_children()
  end

  defp start_children do
    children = []

    opts = [strategy: :one_for_one, name: SFTPAPI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
