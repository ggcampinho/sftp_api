defmodule SFTPServerTest do
  use ExUnit.Case, async: true

  alias SFTPAPI.SFTPServer

  @file_handler {:ssh_sftpd_file, []}
  @user_dir Path.absname("config/sftp_user_dir/test")

  describe "start_daemon/1" do
    test "starts a SSH server accepting connections" do
      assert {:ok, _daemon_ref, port} =
               SFTPServer.start_daemon(@file_handler, port: 0, server: true)

      assert {:ok, conn_ref} = ssh_connect(port)
      assert {:ok, channel_pid} = :ssh_sftp.start_channel(conn_ref)

      assert {:ok, readme} = :ssh_sftp.read_file(channel_pid, "README.md")
      assert readme =~ ~r/^# SFTP API/
    end
  end

  defp ssh_connect(port) do
    opts = [
      auth_methods: 'publickey',
      silently_accept_hosts: true,
      user: 'test',
      user_dir: String.to_charlist(@user_dir)
    ]

    result = :ssh.connect('127.0.0.1', port, opts)

    with {:ok, ref} <- result do
      on_exit(fn -> :ssh.close(ref) end)
      result
    end
  end
end
