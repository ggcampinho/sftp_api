defmodule SFTPAPI.Schema do
  @moduledoc """
  Default schema for Ecto

  It sets the primary and foreign keys as UUIDs.

  ## Example:

      use SFTPAPI.Schema

      schema "db_files" do
        field :path, :string
        field :content, :binary
        field :is_dir, :boolean, default: false
        field :size, :integer, default: 0
      end
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
