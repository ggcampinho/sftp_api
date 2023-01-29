# SFTP API

This project aims to be a proof of concept of an API on top of SFTP like the [one suggested on HackerNews](https://news.ycombinator.com/item?id=18535632).

## Setting up the project

The project requires [Docker](https://docs.docker.com/get-docker/) and [OpenSSH](https://www.openssh.com/) to be installed and running. After that, run:

```bash
make setup
```

This command will setup two directories required to run the application:

* `config/sftp_system_dir` - Holds the server's SSH keys. Check the [requirements of the system directory](https://www.erlang.org/docs/21/man/ssh_file.html#SYSDIR).
* `config/sftp_user_dir` - Holds the configuration for user authentication. Check the [requirements of the user directory](https://www.erlang.org/docs/21/man/ssh_file.html#USERDIR).

Both directories are configured for `dev` and `test` environments. For `dev` your public local SSH
keys are copied over, so you can actually connect using `ssh` in your machine. For `test` all keys
are generated and the tests use those keys to connect. When running the `prod` image in your local
machine, it mounts the `dev` directories for testing only, this folder should never go to
production and the Docker images are made to be connected with production volumes mounted
specfically for that.

## Developing locally

You can access a bash console inside of the main container running:

```bash
make console
```

If you want to run the tests:

```bash
make test
```

To run the application, you can use:

```bash
make run
```

You should be able to connect using in another terminal:

```bash
sftp -oPort=4000 localhost
```

Now, you can play with the SFTP server
```
Connected to localhost.
sftp> ls
sftp> put README.md foo.bar
Uploading README.md to /foo.bar
README.md                                           100% 1783   641.3KB/s   00:00    
sftp> mkdir baz/bar
sftp> ls
baz      foo.bar  
sftp> rmdir baz
sftp> ls
foo.bar  
sftp> get foo.bar README-2.md
Fetching /foo.bar to README-2.md
foo.bar
```

## Releasing to production

To release a new image to production:

```bash
make release
```

To run the application that will be released:

```bash
make server
```