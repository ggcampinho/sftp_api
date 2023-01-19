defmodule SFTPAPI.SFTPServer do
  @moduledoc """
  Implementation of the SFTP server to handle connections

  The SFTP server uses `GenServer` to start a SSH daemon
  accepting connections.

  > Note: The server requires some configuration automatically
  > generated [during setup](../../../README.md#installation).

  ## Server configuration

  * `:port` - TCP port for listening to SSH connections. Defaults
  to `0`, meaning a random free TCP port will be assigned to it.
  * `:server` - Defines if the SSH server should start and listen
  for connections. Defaults to `true`.
  * `:system_dir` - The path of the directory holding the server's
  SSH keys.
  * `:user_dir` - The path of the directory holding the configuration
  for user authentication.

  Here is an example of how to configure

      config :sftp_api, SFTPAPI.SFTPServer,
        port: System.get_env("APP_PORT", "4000") |> String.to_integer()
  """

  use GenServer

  @type start_opt ::
          {:name, GenServer.name()}
          | {:port, integer}
          | {:server, boolean}
          | {:system_dir, Path.t()}
          | {:user_dir, Path.t()}

  @type start_opts :: [start_opt]

  @type start_result :: :ignore | {:error, any} | {:ok, pid}

  require Logger

  @default_port 0
  @default_system_dir "/home/sftp_api/ssh/system_dir/#{Mix.env()}"
  @default_user_dir "/home/sftp_api/ssh/user_dir/#{Mix.env()}"

  defmodule Env do
    @moduledoc false

    defstruct port: nil,
              system_dir: nil,
              user_dir: nil,
              daemon_ref: nil
  end

  # Client

  @doc """
  Starts a process for the SFTP Server linked to the current process.

  ## Options:

    * `:name` - Name used to register the `GenServer`;
    * Other options are described on the [server configuration](#module-server-configuration)
  """
  @spec start_link(start_opts()) :: start_result()
  def start_link(opts) do
    {opts, init_args} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_args, opts)
  end

  # Server (callbacks)

  @impl true
  def init(opts) do
    opts = Keyword.merge(config(), opts)
    server = Keyword.get(opts, :server, true)

    env = %Env{
      port: Keyword.get(opts, :port, @default_port),
      system_dir: Keyword.get(opts, :system_dir, @default_system_dir),
      user_dir: Keyword.get(opts, :user_dir, @default_user_dir)
    }

    case server do
      true -> {:ok, env, {:continue, :ssh_daemon}}
      false -> {:ok, env}
    end
  end

  @impl true
  def handle_continue(:ssh_daemon, env) do
    ssh_opts = [
      auth_methods: 'publickey',
      system_dir: String.to_charlist(env.system_dir),
      user_dir: String.to_charlist(env.user_dir),
      ssh_cli: :no_cli,
      connectfun: &connect_handler/3,
      disconnectfun: &disconnect_handler/1,
      failfun: &failed_auth_handler/3
    ]

    {:ok, ref} = :ssh.daemon(env.port, ssh_opts)
    port = get_port(env.port, ref)

    Logger.info("SFTP server listening on port #{port}")

    {:noreply, %Env{env | daemon_ref: ref, port: port}}
  end

  @doc false
  def connect_handler(user, address, method) do
    Logger.debug("User connected",
      username: to_string(user),
      ip: ip_address(address),
      method: to_string(method)
    )
  end

  @doc false
  def disconnect_handler(reason) do
    Logger.debug("#{reason}")
  end

  @doc false
  def failed_auth_handler(user, address, method) do
    Logger.debug("Failed authentication",
      username: to_string(user),
      ip: ip_address(address),
      method: to_string(method)
    )
  end

  defp ip_address({ip, _port}) do
    ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp get_port(0, daemon_ref) do
    {:ok, info} = :ssh.daemon_info(daemon_ref)
    Keyword.fetch!(info, :port)
  end

  defp get_port(port, _daemon_ref) do
    port
  end

  defp config do
    Application.get_env(:sftp_api, __MODULE__, [])
  end
end
