defmodule SFTPAPI.FileAPI.FileSystem do
  @moduledoc """
  A virtual filesystem implementation using a database

  Instead of doing operations with files directly into the filesystem,
  this module simulates a filesystem using the database as storage.
  """
  alias SFTPAPI.FileAPI.DBFile
  alias SFTPAPI.Repo

  import Ecto.Query

  @type id :: DBFile.id()
  @type content :: binary
  @type offset :: integer
  @type length :: integer

  @type mode :: [:binary | :write | :read]

  @doc """
  Writes the content of the file referenced by `id`

  Append the content to the end of the file's content and increases it's size,
  returning `:ok`.

  If the file doesn't exist, it returns `{:error, :ebadf}`. If the operation
  fails, it returns `{:error, :ebadf}`.
  """
  @spec write(id, content) :: :ok | {:error, :ebadf} | {:error, :enosys}
  def write(id, content) do
    with %DBFile{size: old_size, content: old_content} = db_file <- get_db_file(id) do
      old_content = old_content || ""
      new_content = old_content <> content
      new_size = old_size + byte_size(content)
      changeset = DBFile.changeset(db_file, %{content: new_content, size: new_size})

      case Repo.update(changeset) do
        {:ok, _db_file} -> :ok
        _other -> {:error, :enosys}
      end
    else
      _other -> {:error, :ebadf}
    end
  end

  @doc """
  Reads part of the content of the file referenced by `id`

  It reads `length` bytes of the content, starting on the `offset` defined,
  returning `{:ok, content}`. If the offset is higher than the actual size
  of the content, `:eof` is returned.

  The functions uses the `SUBSTRING` operation in SQL to decrease the memory
  footprint, avoiding to get the full content of a huge file.

  If the file doesn't exist, it returns `{:error, :ebadf}`.
  """
  @spec read(id, offset, length) :: {:ok, content} | :eof | {:error, :ebadf}
  def read(id, offset, length) do
    query =
      from(
        file in DBFile,
        where: file.id == ^id,
        select:
          {fragment("SUBSTRING(? FROM ? FOR ?)", file.content, ^offset, ^length),
           file.size < ^offset}
      )

    case Repo.all(query) do
      [{_, true}] -> :eof
      [{content, false}] -> {:ok, content}
      [] -> {:error, :ebadf}
    end
  end

  @doc """
  Checks if a dir is located under `path`
  """
  @spec dir?(Path.t()) :: boolean
  def dir?(path) do
    case get_db_file_by_path(path) do
      %DBFile{is_dir: dir?} -> dir?
      nil -> false
    end
  end

  @doc """
  Opens a file in the `path`

  Currently, mode needs to include the flag `:binary`. If not, it will return
  `{:error, :enotsup}`.

  When in `:write` mode, an empty file will be created if the file
  doesn't exist, returning `{:ok, id}`. If the file exists, it returns
  `{:ok, id}`. If the `path` is a directory, it will return `{:error, :eisdir}`.

  When in `:read` mode, if the file exists, it returns `{:ok, id}`.
  If the file doesn't exist, it returns `{:error, :enoent}`. If the `path`
  is a directory, it will also return `{:error, :eisdir}`.
  """
  @spec open(Path.t(), mode) ::
          {:ok, id} | {:error, :isdir} | {:error, :enoent} | {:error, :enotsup}
  def open("/" <> _ = path, mode) do
    if :binary in mode do
      open_binary(path, mode -- [:binary])
    else
      {:error, :enotsup}
    end
  end

  defp open_binary(path, mode) do
    cond do
      :write in mode -> open_binary_write(path)
      :read in mode -> open_binary_read(path)
      true -> {:error, :enotsup}
    end
  end

  defp open_binary_write(path) do
    case get_db_file_by_path(path) do
      %DBFile{id: id, is_dir: false} -> {:ok, id}
      %DBFile{} -> {:error, :eisdir}
      nil -> create_empty_db_file(path)
    end
  end

  defp create_empty_db_file(path) do
    {:ok, parent_id} = create_dirs(path)

    changeset = DBFile.changeset(%DBFile{}, %{path: path, content: "", parent_id: parent_id})
    {:ok, %DBFile{id: id}} = Repo.insert(changeset)
    {:ok, id}
  end

  defp create_dirs("/" <> path) do
    case Path.dirname(path) do
      "." -> {:ok, nil}
      dir -> create_dirs(Path.split(dir), "/", nil)
    end
  end

  defp create_dirs([], _path, parent_id) do
    {:ok, parent_id}
  end

  defp create_dirs([dir | rest], path, parent_id) do
    new_path = Path.join(path, dir)
    {:ok, id} = open_dir(new_path, parent_id)
    create_dirs(rest, new_path, id)
  end

  defp open_dir(path, parent_id) do
    case get_db_file_by_path(path) do
      %DBFile{id: id, is_dir: true} -> {:ok, id}
      %DBFile{} -> {:error, :einval}
      nil -> create_dir(path, parent_id)
    end
  end

  defp create_dir(path, parent_id) do
    changeset = DBFile.changeset(%DBFile{}, %{path: path, is_dir: true, parent_id: parent_id})
    {:ok, %DBFile{id: id}} = Repo.insert(changeset)
    {:ok, id}
  end

  defp open_binary_read(path) do
    case get_db_file_by_path(path) do
      %DBFile{id: id, is_dir: false} -> {:ok, id}
      %DBFile{} -> {:error, :eisdir}
      nil -> {:error, :enoent}
    end
  end

  defp get_db_file(id) do
    Repo.get(DBFile, id)
  end

  defp get_db_file_by_path(path) do
    Repo.get_by(DBFile, path: path)
  end
end
