defmodule SFTPAPI.Repo.Migrations.AddDbFilesTimestamps do
  use Ecto.Migration

  def change do
    alter table("db_files") do
      timestamps
    end
  end
end
