defmodule SFTPAPI.FileAPI do
  @moduledoc """
  The file API called from the SFTP Server.

  It implements `:ssh_sftpd_file_api` behaviour. This module is
  to be used as the `file_handler` when calling [`:ssh_sftpd.subsystem_spec/1`](https://www.erlang.org/docs/21/man/ssh_sftpd.html#subsystem_spec-1)
  configuring the SFTP Server to use the database instead of the
  regular filesystem.

  To check the actual file operations, see `SFTPAPI.FileAPI.FileSystem`.
  """

  @behaviour :ssh_sftpd_file_api

  require SFTPAPI.FileAPI.Handler

  import SFTPAPI.FileAPI.Handler

  alias SFTPAPI.FileAPI.FileSystem

  @impl true
  action close(io_device, state) do
    new_state = Keyword.delete(state, :offset)
    {:ok, new_state}
  end

  @impl true
  action delete(path, state) do
    {{:error, :enotsup}, state}
  end

  @impl true
  action del_dir(path, state) do
    {{:error, :enotsup}, state}
  end

  @impl true
  action get_cwd(state) do
    {:file.get_cwd(), state}
  end

  @impl true
  action is_dir(abs_path, state) do
    {FileSystem.dir?(path_relative_to_cwd(abs_path)), state}
  end

  @impl true
  action list_dir(_abs_path, state) do
    {{:error, :enotsup}, state}
  end

  @impl true
  action make_dir(_dir, state) do
    {{:error, :enotsup}, state}
  end

  @impl true
  action make_symlink(_path2, _path, state) do
    {{:error, :enotsup}, state}
  end

  @impl true
  action open(abs_path, flags, state) do
    {FileSystem.open(path_relative_to_cwd(abs_path), flags), state}
  end

  @impl true
  action position(io_device, offset, state) do
    case offset do
      {:bof, offset} -> {{:ok, offset}, [offset: offset]}
      _other -> {{:error, :enotsup}, state}
    end
  end

  @impl true
  action read(io_device, length, state) do
    offset = Keyword.get(state, :offset, 0)
    {FileSystem.read(to_string(io_device), offset, length), state}
  end

  @impl true
  action read_link(_path, state) do
    {{:error, :enotsup}, state}
  end

  @impl true
  action read_link_info(_path, state) do
    {{:error, :enotsup}, state}
  end

  @impl true
  action read_file_info(path, state) do
    {{:error, :enotsup}, state}
  end

  @impl true
  action rename(_path, _path2, state) do
    {{:error, :enotsup}, state}
  end

  @impl true
  action write(io_device, data, state) do
    {FileSystem.write(to_string(io_device), data), state}
  end

  @impl true
  action write_file_info(_path, _info, state) do
    {{:error, :enotsup}, state}
  end
end
