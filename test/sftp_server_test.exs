defmodule SFTPServerTest do
  use ExUnit.Case, async: true

  alias SFTPAPI.SFTPServer

  @user_dir '/home/sftp_api/ssh/user_dir/test'

  setup do
    pid = start_supervised!({SFTPServer, port: 0, server: true})
    %{port: port} = :sys.get_state(pid)

    {:ok, pid: pid, port: port}
  end

  test "accepts connections", %{port: port} do
    assert {:ok, _ref} = ssh_connect(port)
  end

  defp ssh_connect(port) do
    opts = [
      auth_methods: 'publickey',
      silently_accept_hosts: true,
      user: 'test',
      user_dir: @user_dir
    ]

    result = :ssh.connect('127.0.0.1', port, opts)

    with {:ok, ref} <- result do
      on_exit(fn -> :ssh.close(ref) end)
      result
    end
  end
end
