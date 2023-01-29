defmodule SFTPAPI.FileAPI.Handler do
  @moduledoc """
  Helper to add logs and helpers on handlers

  The `:ssh_sftpd_file_api` is great, but it has no logging for
  errors or debugging. This module aims to add those using macros
  to reduce the manual work to add log to every function without
  changing how the behaviour works. If macros were avoided, it
  wouldn't be possible to easily add debug to the args passed to
  the functions.

  It also contains a few helpers to help interacting with the
  `:ssh_sftpd_file_api` behaviour.
  """

  require Logger

  @doc """
  Add logs for debugging and errors

  ## Example:

      require SFTPAPI.FileAPI.Handler
      import SFTPAPI.FileAPI.Handler

      action get_cwd(state) do
        {:file.get_cwd(), state}
      end

  If the log `:level` is set to `:debug`, the following output will
  be shown:

      23:17:43.832 [debug] get_cwd args:
         state = []
      23:17:43.832 [debug] get_cwd result: {{:ok, '/home/sftp_api/app'}, []}

  If an error occurs, an output like the one below will be shown:

      18:41:38.988 [error] ** (RuntimeError) boom!
          (sftp_api 0.1.0) lib/sftp_api/file_api.ex:27: SFTPAPI.FileAPI.get_cwd/1
          (ssh 4.15.1) ssh_sftpd.erl:98: :ssh_sftpd.init/1
          (ssh 4.15.1) ssh_client_channel.erl:167: :ssh_client_channel.init/1
          (stdlib 4.2) gen_server.erl:851: :gen_server.init_it/2
          (stdlib 4.2) gen_server.erl:814: :gen_server.init_it/6
          (stdlib 4.2) proc_lib.erl:240: :proc_lib.init_p_do_apply/3

  """
  defmacro action(clause = {name, _, args}, do: expression) do
    debug_args = prepare_log_args(args)

    quote do
      def unquote(clause) do
        try do
          SFTPAPI.FileAPI.Handler.log_args(unquote(name), unquote(debug_args))
          result = unquote(expression)
          SFTPAPI.FileAPI.Handler.log_result(unquote(name), result)
          result
        rescue
          error ->
            SFTPAPI.FileAPI.Handler.log_error(error, __STACKTRACE__)
            reraise error, __STACKTRACE__
        end
      end
    end
  end

  defp prepare_log_args(args) do
    for arg = {arg_name, _, _} <- args || [],
        !String.starts_with?(Atom.to_string(arg_name), "_") do
      {arg_name, arg}
    end
  end

  @doc false
  def log_args(fun, debug_args) do
    Logger.debug(fn ->
      message =
        for {name, arg} <- debug_args do
          "\n\t#{name} = #{inspect(arg)}"
        end

      "#{fun} args: #{message}"
    end)
  end

  @doc false
  def log_result(name, result) do
    Logger.debug("#{name} result: #{inspect(result)}")
  end

  @doc false
  def log_error(error, stacktrace) do
    Logger.error(Exception.format(:error, error, stacktrace))
  end

  @doc """
  Makes a path relative to the cwd

  It will return the relative path to the cwd, but looking like an
  absolute path.

  ## Example:

      iex> File.cwd!()
      "/home/sftp_api/app"
      iex> SFTPAPI.FileAPI.Handler.path_relative_to_cwd('/home/sftp_api/app/foo')
      "/foo"
  """
  @spec path_relative_to_cwd(charlist) :: Path.t()
  def path_relative_to_cwd(abs_path) do
    path = abs_path |> to_string() |> Path.relative_to_cwd()
    Path.join("/", path)
  end

  def path_without_cwd(abs_path) do
    path_without_cwd(Path.split(abs_path), Path.split(File.cwd!()))
  end

  defp path_without_cwd([dir | rest1], [dir | rest2]) do
    path_without_cwd(rest1, rest2)
  end

  defp path_without_cwd(path, _cwd) do
    Path.join(["/"] ++ path)
  end
end
