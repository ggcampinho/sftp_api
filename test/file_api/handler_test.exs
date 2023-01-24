defmodule SFTPAPI.FileAPI.HandlerTest do
  use ExUnit.Case

  alias ExUnit.CaptureLog
  alias SFTPAPI.FileAPI.Handler

  setup do
    old_level = Logger.level()
    Logger.configure(level: :debug)

    on_exit(fn ->
      Logger.configure(level: old_level)
    end)
  end

  defmodule Dummy do
    require SFTPAPI.FileAPI.Handler

    import SFTPAPI.FileAPI.Handler, only: [action: 2]

    action plus_1(n, state) do
      {n + 1, state}
    end

    action raise_error do
      raise "boom!"
    end
  end

  describe "macro action" do
    test "wraps regular functions" do
      message =
        CaptureLog.capture_log(fn ->
          assert {2, []} == Dummy.plus_1(1, [])
        end)

      assert message =~ "plus_1 args:"
      assert message =~ "\tn = 1"
      assert message =~ "\tstate = []"
      assert message =~ "plus_1 result: {2, []}"
    end

    test "wraps errors" do
      message =
        CaptureLog.capture_log(fn ->
          assert_raise RuntimeError, fn ->
            Dummy.raise_error()
          end
        end)

      assert message =~ "boom!"
      assert message =~ "test/file_api/handler_test.exs:26"
    end
  end

  describe "path_relative_to_cwd/1" do
    test "makes the path relative to the cwd" do
      {:ok, cwd} = :file.get_cwd()

      assert "/foo" = Handler.path_relative_to_cwd(cwd ++ '/foo')
      assert "/foo/bar" = Handler.path_relative_to_cwd(cwd ++ '/foo/bar')

      assert "/foo" = Handler.path_relative_to_cwd('/foo')
    end
  end
end
