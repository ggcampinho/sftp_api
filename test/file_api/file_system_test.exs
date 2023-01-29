defmodule SFTPAPI.FileAPI.FileSystemTest do
  use SFTPAPI.DataCase, async: true

  alias SFTPAPI.FileAPI.DBFile
  alias SFTPAPI.FileAPI.FileSystem

  describe "write/3" do
    test "saves the content in an open file" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo")

      assert :ok = FileSystem.write(id, "bar", 0)
      assert %{content: "bar", size: 3} = Repo.get(DBFile, id)
    end

    test "skips to the offset" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert :ok = FileSystem.write(id, "qux", 2)
      assert %{content: "baquxz", size: 6} = Repo.get(DBFile, id)
    end

    test "increases the size of the db file" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert :ok = FileSystem.write(id, "qux", 5)
      assert %{content: "barbaqux", size: 8} = Repo.get(DBFile, id)
    end

    test "returns error if db file is missing" do
      assert {:error, :ebadf} = FileSystem.write(Ecto.UUID.generate(), "bar", 0)
    end
  end

  describe "read/3" do
    test "reads the content for length" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert {:ok, "bar"} = FileSystem.read(id, 0, 3)
      assert {:ok, "barba"} = FileSystem.read(id, 0, 5)
      assert {:ok, "barbaz"} = FileSystem.read(id, 0, 7)
    end

    test "reads from offset" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert {:ok, "arb"} = FileSystem.read(id, 1, 3)
      assert {:ok, "arbaz"} = FileSystem.read(id, 1, 5)
      assert {:ok, "arbaz"} = FileSystem.read(id, 1, 7)
    end

    test "returns eof if offset is after end" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert :eof = FileSystem.read(id, 7, 0)
    end

    test "returns error if db file is missing" do
      assert {:error, :ebadf} = FileSystem.read(Ecto.UUID.generate(), 0, 1)
    end
  end

  describe "dir?/1" do
    test "checks if db file is a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: true)
      {:ok, _} = insert_db_file("/bar", is_dir: false)

      assert FileSystem.dir?("/foo")
      refute FileSystem.dir?("/bar")
    end
  end

  describe "open/2 mode [:binary, :write]" do
    @mode [:binary, :write]

    test "returns the id of existing file" do
      {:ok, %{id: id}} = insert_db_file("/foo")

      assert {:ok, ^id} = FileSystem.open("/foo", @mode)
    end

    test "creates a file if it doesn't exist" do
      assert {:ok, id} = FileSystem.open("/foo", @mode)

      assert %DBFile{
               path: "/foo",
               content: nil,
               size: 0,
               is_dir: false,
               parent_id: parent_id
             } = Repo.get(DBFile, id)

      assert %DBFile{
               path: "/",
               is_dir: true,
               parent_id: nil
             } = Repo.get(DBFile, parent_id)
    end

    test "creates the dirs that don't exist" do
      assert {:ok, id} = FileSystem.open("/foo/bar/baz", @mode)

      assert %DBFile{
               path: "/foo/bar/baz",
               content: nil,
               size: 0,
               is_dir: false,
               parent_id: parent_id
             } = Repo.get(DBFile, id)

      assert %DBFile{
               path: "/foo/bar",
               is_dir: true,
               parent_id: parent_id
             } = Repo.get(DBFile, parent_id)

      assert %DBFile{
               path: "/foo",
               is_dir: true,
               parent_id: parent_id
             } = Repo.get(DBFile, parent_id)

      assert %DBFile{
               path: "/",
               is_dir: true,
               parent_id: nil
             } = Repo.get(DBFile, parent_id)
    end

    test "returns error if it's a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: true)

      assert {:error, :eisdir} = FileSystem.open("/foo", @mode)
    end

    test "returns error if component is not a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: false)
      assert {:error, :enotdir} = FileSystem.open("/foo/bar", @mode)
    end
  end

  describe "open/2 mode [:binary, :read]" do
    @mode [:binary, :read]

    test "returns the id of existing file" do
      {:ok, %{id: id}} = insert_db_file("/foo")

      assert {:ok, ^id} = FileSystem.open("/foo", @mode)
    end

    test "returns error if it doesn't exist" do
      assert {:error, :enoent} = FileSystem.open("/foo", @mode)
    end

    test "returns error if it's a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: true)

      assert {:error, :eisdir} = FileSystem.open("/foo", @mode)
    end
  end

  describe "open/2 invalid mode" do
    test "returns error without binary mode" do
      assert {:error, :enotsup} = FileSystem.open("/foo", [:read])
    end

    test "returns error with only binary mode" do
      assert {:error, :enotsup} = FileSystem.open("/foo", [:binary])
    end
  end

  describe "read_link/1" do
    test "returns error einval for existing db files" do
      {:ok, _} = insert_db_file("/foo")

      assert {:error, :einval} = FileSystem.read_link("/foo")
    end

    test "returns error enoent for missing db files" do
      assert {:error, :enoent} = FileSystem.read_link("/foo")
    end
  end

  describe "read_file_info/1" do
    test "returns stats for the db file" do
      {:ok, _} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert {:ok, record} = FileSystem.read_file_info("/foo")

      assert %{
               access: :read_write,
               atime: {{_, _, _}, {_, _, _}},
               ctime: {{_, _, _}, {_, _, _}},
               gid: 0,
               inode: 0,
               links: 1,
               major_device: 0,
               minor_device: 0,
               mode: 33188,
               mtime: {{_, _, _}, {_, _, _}},
               size: 6,
               type: :regular,
               uid: 0
             } = File.Stat.from_record(record)
    end

    test "returns stats for the dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: true)

      assert {:ok, record} = FileSystem.read_file_info("/foo")

      assert %{
               type: :directory,
               mode: 17901
             } = File.Stat.from_record(record)
    end

    test "returns error for missing db files" do
      assert {:error, :einval} = FileSystem.read_file_info("/foo")
    end
  end

  describe "list_dir/1" do
    test "returns the db files in a dir" do
      %{id: root_id} = Repo.get_by(DBFile, path: "/")
      {:ok, %{id: dir_id}} = insert_db_file("/foo", parent_id: root_id, is_dir: true)
      {:ok, _} = insert_db_file("/foo/bar", parent_id: dir_id)
      {:ok, _} = insert_db_file("/foo/baz", parent_id: dir_id)

      assert {:ok, ["bar", "baz"]} == FileSystem.list_dir("/foo")
    end

    test "returns error if db file is not a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: false)

      assert {:error, :enoent} == FileSystem.list_dir("/foo")
    end

    test "returns error if db file is missing" do
      assert {:error, :enoent} == FileSystem.list_dir("/foo")
    end
  end

  describe "make_dir/1" do
    test "makes a dir db file" do
      %{id: root_id} = Repo.get_by(DBFile, path: "/")

      assert :ok == FileSystem.make_dir("/foo")
      assert %{is_dir: true, parent_id: ^root_id} = Repo.get_by(DBFile, path: "/foo")
    end

    test "makes recursively a dir db file" do
      %{id: root_id} = Repo.get_by(DBFile, path: "/")

      assert :ok == FileSystem.make_dir("/foo/bar")
      assert %{id: foo_id, is_dir: true, parent_id: ^root_id} = Repo.get_by(DBFile, path: "/foo")
      assert %{is_dir: true, parent_id: ^foo_id} = Repo.get_by(DBFile, path: "/foo/bar")
    end

    test "returns error if db file is not a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: false)

      assert {:error, :enotdir} == FileSystem.make_dir("/foo")
    end

    test "returns error if component is not a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: false)

      assert {:error, :enotdir} == FileSystem.make_dir("/foo/bar")
    end
  end

  describe "delete/1" do
    test "deletes the db file" do
      {:ok, %{id: id}} = insert_db_file("/foo", is_dir: false)

      assert :ok == FileSystem.delete("/foo")
      assert nil == Repo.get(DBFile, id)
    end

    test "returns error if the db file is a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: true)

      assert {:error, :enoent} == FileSystem.delete("/foo")
    end
  end

  describe "delete_dir/1" do
    test "deletes recursively the db file" do
      %{id: root_id} = Repo.get_by(DBFile, path: "/")
      {:ok, %{id: foo_id}} = insert_db_file("/foo", is_dir: true, parent_id: root_id)
      {:ok, %{id: bar_id}} = insert_db_file("/foo/bar", parent_id: foo_id)
      {:ok, %{id: baz_id}} = insert_db_file("/foo/baz", parent_id: foo_id)

      assert :ok == FileSystem.delete_dir("/foo")
      assert nil == Repo.get(DBFile, foo_id)
      assert nil == Repo.get(DBFile, bar_id)
      assert nil == Repo.get(DBFile, baz_id)
    end

    test "returns error if the db file is the root" do
      assert {:error, :enoent} == FileSystem.delete_dir("/")
    end

    test "returns error if the db file is not a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: false)

      assert {:error, :enoent} == FileSystem.delete_dir("/foo")
    end
  end

  defp insert_db_file(path, attrs \\ []) do
    db_file = struct(%DBFile{}, [path: path] ++ attrs)
    Repo.insert(db_file)
  end
end
