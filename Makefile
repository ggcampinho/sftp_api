# console: Opens the console inside of the dev container
.PHONY: console
console:
	@docker-compose run --rm sftp_api bash

# build: Builds the application container in dev mode
.PHONY: build
build:
	@docker-compose build

# release: Releases the application image for prod tagging with `sftp_api/latest`
.PHONY: release
release:
	@docker build -t sftp_api/latest -f Dockerfile.prod .

# run: Run the app in dev
.PHONY: run
run: run-dev

# run-dev: Run the app inside the dev container
.PHONY: run-dev
run-dev:
	@docker-compose run --rm sftp_api

# run-prod: Run the app inside the prod container tagged with `sftp_api/latest`
.PHONY: run-prod
run-prod:
	@docker run sftp_api/latest

# server: Release and run the release
.PHONY: server
server: release run-prod

# test: Run the tests
.PHONY: test
test:
	@docker-compose run --rm sftp_api mix test

