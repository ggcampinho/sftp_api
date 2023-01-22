defmodule SFTPAPI.SFTPServer do
  @moduledoc """
  Implementation of the SFTP server to handle connections

  The SFTP server starts a (SSH daemon)[https://www.erlang.org/docs/21/man/ssh.html#daemon-1]
  with a file handler implementing the behaviour `:ssh_sftpd_file_api`.

  The server is started on the same process because the `:ssh` module
  already starts the connections under their own supervision tree.

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

  require Logger

  @typedoc """
  A tuple containing a module handling the SFTP operations and the initial state.

  The module should implement the behaviour `:ssh_sftpd_file_api`.
  """
  @type file_handler :: {module, init_state :: any}

  @typedoc """
  The options to configure the SFTP server.

  Described in [server configuration](#module-server-configuration).
  """
  @type start_opts :: [
          {:name, GenServer.name()}
          | {:port, tcp_port :: integer}
          | {:server, boolean}
          | {:system_dir, Path.t()}
          | {:user_dir, Path.t()}
        ]

  @typedoc """
  The result of starting the SFTP server.

  If successful it returns `{:ok, pid, tcp_port}`, if it fails returns
  `{:error, reason}`.
  """
  @type start_result :: {:ok, pid, tcp_port :: integer} | {:error, reason :: any}

  @default_port 0
  @default_system_dir Path.absname("config/sftp_system_dir/#{Mix.env()}")
  @default_user_dir Path.absname("config/sftp_user_dir/#{Mix.env()}")

  defmodule Config do
    @moduledoc false

    defstruct port: nil,
              server: nil,
              system_dir: nil,
              user_dir: nil
  end

  @doc """
  Starts a SSH daemon with a SFTP subsystem.

  The `file_handler` is a module representing the SFTP subsystem, it
  will be called every time a file operation happens.

  ## Options:

    * Same as in [server configuration](#module-server-configuration)
  """
  @spec start_daemon(file_handler) :: start_result
  @spec start_daemon(file_handler, start_opts) :: start_result
  def start_daemon(file_handler, opts \\ []) do
    config = get_config(opts)
    result = start_ssh_daemon(file_handler, config)

    with {:ok, ref} <- result do
      port = get_port(config.port, ref)
      Logger.info("SFTP server listening on port #{port}")
      {:ok, ref, port}
    end
  end

  defp get_config(opts) do
    opts = Keyword.merge(config(), opts)

    %Config{
      port: Keyword.get(opts, :port, @default_port),
      server: Keyword.get(opts, :server, true),
      system_dir: Keyword.get(opts, :system_dir, @default_system_dir),
      user_dir: Keyword.get(opts, :user_dir, @default_user_dir)
    }
  end

  defp start_ssh_daemon(file_handler, config) do
    cwd = File.cwd!() |> String.to_charlist()
    system_dir = String.to_charlist(config.system_dir)
    user_dir = String.to_charlist(config.user_dir)

    sftpd_subsystem =
      :ssh_sftpd.subsystem_spec(
        cwd: cwd,
        root: cwd,
        file_handler: file_handler
      )

    ssh_opts = [
      auth_methods: 'publickey',
      system_dir: system_dir,
      user_dir: user_dir,
      subsystems: [sftpd_subsystem],
      connectfun: &connect_handler/3,
      disconnectfun: &disconnect_handler/1,
      failfun: &failed_auth_handler/3
    ]

    :ssh.daemon(config.port, ssh_opts)
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
