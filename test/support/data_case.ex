defmodule SFTPAPI.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring access to the
  application's data layer.

  If the test case interacts with the database, we enable the SQL sandbox,
  so changes done to the database are reverted at the end of every test.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias SFTPAPI.Repo

      import SFTPAPI.DataCase
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(SFTPAPI.Repo)
  end
end
