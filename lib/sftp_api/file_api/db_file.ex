defmodule SFTPAPI.FileAPI.DBFile do
  @moduledoc """
  Represents a virtual file stored in the database
  """
  use SFTPAPI.Schema

  @type id :: Ecto.UUID.t()
  @type path :: String.t()
  @type content :: binary

  @type t :: %__MODULE__{
          id: id,
          path: path,
          content: content | nil,
          is_dir: boolean,
          size: integer,
          parent_id: id,
          parent: t,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type params :: %{
          path: path,
          content: content | nil,
          is_dir: boolean,
          size: integer
        }

  schema "db_files" do
    field(:path, :string)
    field(:content, :binary)
    field(:is_dir, :boolean, default: false)
    field(:size, :integer, default: 0)

    belongs_to(:parent, __MODULE__)

    timestamps()
  end

  @doc """
  Creates a changeset

  It requires `path`, `is_dir` and `size` attributes, and checks
  if `path` is unique.
  """
  @spec changeset(t, params) :: Ecto.Changeset.t(t)
  def changeset(db_file, params \\ %{}) do
    db_file
    |> Ecto.Changeset.cast(params, [:path, :content, :is_dir, :size, :parent_id])
    |> Ecto.Changeset.validate_required([:path, :is_dir, :size])
    |> Ecto.Changeset.unique_constraint([:path])
  end
end
