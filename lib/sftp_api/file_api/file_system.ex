defmodule SFTPAPI.FileAPI.FileSystem do
  @moduledoc """
  A virtual filesystem implementation using a database

  Instead of doing operations with files directly into the filesystem,
  this module simulates a filesystem using the database as storage.

  The concurrency was left out of scope in some operations, but they will
  fail instead of executing a wrong command.
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

  The functions uses the `OVERLAY` operation in SQL to decrease the memory
  footprint, avoiding to get the full content of a huge file.

  If the file doesn't exist, it returns `{:error, :ebadf}`.
  """
  @spec write(id, content, offset) :: :ok | {:error, :ebadf} | {:error, :enosys}
  def write(id, content, offset) do
    content_end = offset + byte_size(content)

    query =
      from(
        file in DBFile,
        where: file.id == ^id,
        update: [
          set: [
            content:
              fragment(
                "OVERLAY(COALESCE(?, '') PLACING ? FROM ?)",
                file.content,
                ^content,
                ^(offset + 1)
              ),
            size: fragment("GREATEST(?, ?)", file.size, ^content_end)
          ]
        ]
      )

    case Repo.update_all(query, []) do
      {1, nil} -> :ok
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
          {fragment(
             "SUBSTRING(COALESCE(?, '') FROM ? FOR ?)",
             file.content,
             ^(offset + 1),
             ^length
           ), file.size <= ^offset}
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
    with {:ok, parent_id} <- create_dirs(path) do
      changeset = DBFile.changeset(%DBFile{}, %{path: path, content: "", parent_id: parent_id})
      {:ok, %DBFile{id: id}} = Repo.insert(changeset)
      {:ok, id}
    end
  end

  defp open_binary_read(path) do
    case get_db_file_by_path(path) do
      %DBFile{id: id, is_dir: false} -> {:ok, id}
      %DBFile{} -> {:error, :eisdir}
      nil -> {:error, :enoent}
    end
  end

  defp get_db_file_by_path(path) do
    Repo.get_by(DBFile, path: path)
  end

  @doc """
  Reads a link in `path`

  We don't support links, so this will always return error. It will return
  `{:error, :einval}` when file exists and `{:error, :enoent}` when it doesn't.
  """
  @spec read_link(Path.t()) :: {:error, :einval} | {:error, :enoent}
  def read_link(path) do
    case get_db_file_by_path(path) do
      %DBFile{} -> {:error, :einval}
      nil -> {:error, :enoent}
    end
  end

  @doc """
  Reads the file stats for a `path`

  This returns a fake `File.Stat` struct that simulates a file in the
  filesystem. If the file exists, it returns `{:ok, stats}`, otherwise
  it returns `{:error, :einval}`.
  """
  @spec read_file_info(Path.t()) :: {:ok, :file.file_info()} | {:error, :einval}
  def read_file_info(path) do
    case get_db_file_by_path(path) do
      %DBFile{size: size, is_dir: dir?, inserted_at: inserted_at} ->
        time =
          {{inserted_at.year, inserted_at.month, inserted_at.day},
           {inserted_at.hour, inserted_at.minute, inserted_at.second}}

        file_stat = %File.Stat{
          access: :read_write,
          atime: time,
          ctime: time,
          gid: 0,
          inode: 0,
          links: 1,
          major_device: 0,
          minor_device: 0,
          mode: file_stat_mode(dir?),
          mtime: time,
          size: size,
          type: file_stat_type(dir?),
          uid: 0
        }

        {:ok, File.Stat.to_record(file_stat)}

      nil ->
        {:error, :einval}
    end
  end

  defp file_stat_type(true), do: :directory
  defp file_stat_type(false), do: :regular

  # Hard-coded values to simulate the mode
  defp file_stat_mode(true), do: 17901
  defp file_stat_mode(false), do: 33188

  @doc """
  List children files from a dir

  If `path` is a dir, it returns all files and dirs that are there children,
  returning `{:ok, children}`. Otherwise, it returns `{:error, :enoent}`.
  """
  @spec list_dir(Path.t()) :: {:ok, [Path.t()]} | {:error, :enoent}
  def list_dir(path) do
    case get_db_file_by_path(path) do
      %DBFile{id: id, is_dir: true} -> {:ok, list_dir_children(id)}
      _other -> {:error, :enoent}
    end
  end

  defp list_dir_children(parent_id) do
    query =
      from(
        file in DBFile,
        where: file.parent_id == ^parent_id,
        select: file.path
      )

    Enum.map(Repo.all(query), &Path.basename/1)
  end

  @doc """
  Makes a dir in `path`

  If it is successful or if the dir already exists, it returns `:ok`. If
  some component of `path` is not a dir, it returns `{:error, :enotdir}`.
  """
  @spec make_dir(Path.t()) :: :ok | {:error, :enotdir}
  def make_dir(path) do
    with {:ok, _id} <- create_dirs(Path.split(path), "/", nil) do
      :ok
    end
  end

  defp create_dirs(path) do
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

    with {:ok, id} <- open_dir(new_path, parent_id) do
      create_dirs(rest, new_path, id)
    end
  end

  defp open_dir(path, parent_id) do
    case get_db_file_by_path(path) do
      %DBFile{id: id, is_dir: true} -> {:ok, id}
      %DBFile{} -> {:error, :enotdir}
      nil -> create_dir(path, parent_id)
    end
  end

  defp create_dir(path, parent_id) do
    changeset = DBFile.changeset(%DBFile{}, %{path: path, is_dir: true, parent_id: parent_id})
    {:ok, %DBFile{id: id}} = Repo.insert(changeset)
    {:ok, id}
  end

  @doc """
  Deletes a file in `path`

  If the file exists, it will be deleted and return `:ok`, otherwise it
  returns `{:error, :enoent}`.

  To remove a dir, please use `delete_dir/1`.
  """
  @spec delete(Path.t()) :: :ok | {:error, :enoent}
  def delete(path) do
    delete(path, false)
  end

  @doc """
  Deletes a dir in `path`

  If the dir exists, it will be deleted and return `:ok`, otherwise it
  returns `{:error, :enoent}`.

  To remove a file, please use `delete/1`.
  """
  @spec delete(Path.t()) :: :ok | {:error, :enoent}
  def delete_dir(path) do
    delete(path, true)
  end

  defp delete("/", _dir?) do
    {:error, :enoent}
  end

  defp delete(path, dir?) do
    query =
      from(
        file in DBFile,
        where: file.path == ^path and file.is_dir == ^dir?
      )

    case Repo.delete_all(query) do
      {1, nil} -> :ok
      _ -> {:error, :enoent}
    end
  end
end
