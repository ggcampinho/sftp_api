defmodule SFTPAPI.Repo.Migrations.InsertRootDbFile do
  use Ecto.Migration

  alias SFTPAPI.Repo

  import Ecto.Query

  def up do
    now = DateTime.utc_now()

    Repo.insert_all("db_files", [
      %{id: Ecto.UUID.bingenerate(), path: "/", is_dir: true, inserted_at: now, updated_at: now}
    ])
  end

  def down do
    query =
      from(
        file in "db_files",
        where: file.path == "/"
      )

    Repo.delete_all(query)
  end
end
