defmodule SFTPAPI.Repo.Migrations.CreateDbFiles do
  use Ecto.Migration

  def change do
    create table("db_files") do
      add(:path, :string, null: false)
      add(:content, :binary)
      add(:is_dir, :boolean, null: false, default: false)
      add(:size, :integer, null: false, default: 0)
      add(:parent_id, references("db_files", on_delete: :delete_all, on_update: :update_all))
    end

    create(unique_index("db_files", [:path]))
  end
end
