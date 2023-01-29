defmodule SFTPAPI.FileAPITest do
  use SFTPAPI.DataCase, async: true

  alias SFTPAPI.FileAPI
  alias SFTPAPI.FileAPI.DBFile

  @cwd :file.get_cwd() |> elem(1)

  describe "write/3" do
    test "saves the content in an open file" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo")

      assert {:ok, []} = FileAPI.write(id, "bar", [])
      assert %{content: "bar", size: 3} = Repo.get(DBFile, id)
    end

    test "skips to the offset" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo", content: "bar", size: 3)

      assert {:ok, [offset: 3]} = FileAPI.write(id, "baz", offset: 3)
      assert %{content: "barbaz", size: 6} = Repo.get(DBFile, id)
    end
  end

  describe "read/3" do
    test "reads the content for length" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert {{:ok, "bar"}, []} = FileAPI.read(id, 3, [])
    end

    test "reads from offset" do
      {:ok, %DBFile{id: id}} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert {{:ok, "baz"}, [offset: 3]} = FileAPI.read(id, 3, offset: 3)
    end
  end

  describe "dir?/1" do
    test "checks if file is a dir" do
      {:ok, _} = insert_db_file("/foo", is_dir: true)

      assert {true, []} = FileAPI.is_dir(@cwd ++ '/foo', [])
    end
  end

  describe "open/3" do
    test "returns the id of the file" do
      {:ok, %{id: id}} = insert_db_file("/foo")

      assert {{:ok, ^id}, []} = FileAPI.open(@cwd ++ '/foo', [:binary, :write], [])
    end
  end

  describe "read_link/2" do
    test "returns error einval for existing files" do
      {:ok, _} = insert_db_file("/foo")

      assert {{:error, :einval}, []} = FileAPI.read_link(@cwd ++ '/foo', [])
    end
  end

  describe "read_link_info/2" do
    test "returns stats for the file" do
      {:ok, _} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert {{:ok, record}, []} = FileAPI.read_link_info(@cwd ++ '/foo', [])

      assert %{
               size: 6,
               type: :regular
             } = File.Stat.from_record(record)
    end
  end

  describe "read_file_info/2" do
    test "returns stats for the file" do
      {:ok, _} = insert_db_file("/foo", content: "barbaz", size: 6)

      assert {{:ok, record}, []} = FileAPI.read_file_info(@cwd ++ '/foo', [])

      assert %{
               size: 6,
               type: :regular
             } = File.Stat.from_record(record)
    end
  end

  describe "list_dir/1" do
    test "returns the files in a dir" do
      %{id: root_id} = Repo.get_by(DBFile, path: "/")
      {:ok, _} = insert_db_file("/foo", parent_id: root_id)

      assert {{:ok, ["foo"]}, []} == FileAPI.list_dir(@cwd ++ '/', [])
    end
  end

  describe "make_dir/1" do
    test "makes a dir" do
      assert {:ok, []} == FileAPI.make_dir(@cwd ++ '/foo', [])
      assert %{path: "/foo", is_dir: true} = Repo.get_by(DBFile, path: "/foo")
    end
  end

  describe "delete/1" do
    test "deletes the file" do
      {:ok, %{id: id}} = insert_db_file("/foo", is_dir: false)

      assert {:ok, []} == FileAPI.delete(@cwd ++ '/foo', [])
      assert nil == Repo.get(DBFile, id)
    end
  end

  describe "delete_dir/1" do
    test "deletes recursively the dir" do
      %{id: root_id} = Repo.get_by(DBFile, path: "/")
      {:ok, %{id: foo_id}} = insert_db_file("/foo", is_dir: true, parent_id: root_id)
      {:ok, %{id: bar_id}} = insert_db_file("/foo/bar", parent_id: foo_id)
      {:ok, %{id: baz_id}} = insert_db_file("/foo/baz", parent_id: foo_id)

      assert {:ok, []} == FileAPI.del_dir(@cwd ++ '/foo', [])
      assert nil == Repo.get(DBFile, foo_id)
      assert nil == Repo.get(DBFile, bar_id)
      assert nil == Repo.get(DBFile, baz_id)
    end
  end

  defp insert_db_file(path, attrs \\ []) do
    db_file = struct(%DBFile{}, [path: path] ++ attrs)
    Repo.insert(db_file)
  end
end
