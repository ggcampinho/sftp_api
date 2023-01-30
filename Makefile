MAKEFILE_PATH := ${abspath ${MAKEFILE_LIST}}
MAKEFILE_DIR := ${dir ${MAKEFILE_PATH}}
RELEASE_TAG := sftp_api/latest

# It should match the target name
SFTP_SYSTEM_DIR := ${MAKEFILE_DIR}config/sftp_system_dir
SFTP_SYSTEM_DIR_VOLUME_OPTS := ${SFTP_SYSTEM_DIR}/dev:/home/sftp_api/app/config/sftp_system_dir/prod

# It should match the target name
SFTP_USER_DIR := ${MAKEFILE_DIR}config/sftp_user_dir
SFTP_USER_DIR_VOLUME_OPTS := ${SFTP_USER_DIR}/dev:/home/sftp_api/app/config/sftp_user_dir/prod

# clean: Clean all the setup
.PHONY: clean
clean:
	@rm -rf ${SFTP_SYSTEM_DIR} ${SFTP_USER_DIR}

# console: Executes `console-dev`
.PHONY: console
console: console-dev

# console-dev: Executes `run-console-dev`
.PHONY: console-dev
console-dev: run-console-dev

# console-prod: Executes `release` and `run-console-dev`
.PHONY: console-prod
console-prod: release run-console-prod

# run-console-dev: Opens the console inside the dev container
.PHONY: run-console-dev
run-console-dev:
	@docker-compose run --rm sftp_api bash

# run-console-prod: Opens the console inside the prod container tagged with $RELEASE_TAG
.PHONY: run-console-prod
run-console-prod:
	@docker run -i -v ${SFTP_SYSTEM_DIR_VOLUME_OPTS} -v ${SFTP_USER_DIR_VOLUME_OPTS} ${RELEASE_TAG} sh

# config/sftp_system_dir: Generate the keys required for the SFTP server
config/sftp_system_dir:
	@mkdir -p ${SFTP_SYSTEM_DIR}/dev/etc/ssh
	@ssh-keygen -A -f ${SFTP_SYSTEM_DIR}/dev
	@mv ${SFTP_SYSTEM_DIR}/dev/etc/ssh/* ${SFTP_SYSTEM_DIR}/dev
	@rmdir ${SFTP_SYSTEM_DIR}/dev/etc/ssh ${SFTP_SYSTEM_DIR}/dev/etc
	@cp -r ${SFTP_SYSTEM_DIR}/dev ${SFTP_SYSTEM_DIR}/test

# config/sftp_user_dir: Add your keys to the user dir, allowing you to connect to the SFTP server
config/sftp_user_dir:
	@mkdir -p ${SFTP_USER_DIR}/dev
	@touch ${SFTP_USER_DIR}/dev/authorized_keys
	@chmod 600 ${SFTP_USER_DIR}/dev/authorized_keys
	@cp -r ${SFTP_USER_DIR}/dev ${SFTP_USER_DIR}/test

	@cat ${HOME}/.ssh/id*.pub > ${SFTP_USER_DIR}/dev/authorized_keys

	@ssh-keygen -t ed25519 -N "" -q -f ${SFTP_USER_DIR}/test/id_ed25519
	@cat ${SFTP_USER_DIR}/test/id*.pub > ${SFTP_USER_DIR}/test/authorized_keys

# setup: Executes `config/sftp_system_dir`, `config/sftp_user_dir` and `build`
.PHONY: setup
setup: config/sftp_system_dir config/sftp_user_dir build migrate

# migrate: Creates and migrates the database
.PHONY: migrate
migrate:
	@docker-compose run --rm sftp_api mix do ecto.create, ecto.migrate
	@docker-compose run -e MIX_ENV=test --rm sftp_api mix do ecto.create, ecto.migrate

# build: Builds the application container in dev mode
.PHONY: build
build:
	@docker-compose build

# release: Releases the application image for prod tagging with $RELEASE_TAG
.PHONY: release
release:
	@docker build -t ${RELEASE_TAG} -f Dockerfile.prod .

# run: Executes `run-dev`
.PHONY: run
run: run-dev

# run-dev: Run the app inside the dev container
.PHONY: run-dev
run-dev:
	@docker-compose up --remove-orphans --abort-on-container-exit
	@docker-compose down

# run-prod: Run the app inside the prod container tagged with $RELEASE_TAG
.PHONY: run-prod
run-prod:
	@docker run -p "4000:4000" -v ${SFTP_SYSTEM_DIR_VOLUME_OPTS} -v ${SFTP_USER_DIR_VOLUME_OPTS} ${RELEASE_TAG}

# server: Executes `release` and `run-prod`
.PHONY: server
server: release run-prod

# test: Run the tests
.PHONY: test
test:
	@docker-compose run --rm sftp_api mix test

