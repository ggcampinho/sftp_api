# SFTP API

This project aims to be a proof of concept of an API on top of SFTP like the one suggested on (https://news.ycombinator.com/item?id=18535632).

## Installation

The project requires [Docker](https://docs.docker.com/get-docker/) to be installed and running. After that, run:

```bash
make build
```

## Development

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

## Production

To release a new image to production:

```bash
make release
```

To run the application that will be released:

```bash
make server
```