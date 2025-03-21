#
# OS2display infrastructure makefile.

MAKEFLAGS += --no-print-directory

# =============================================================================
# MAIN COMMAND TARGETS
# =============================================================================
.DEFAULT_GOAL := help

help: ## Display a list of the public targets
# Find lines that starts with a word-character, contains a colon and then a
# doublehash (underscores are not word-characters, so this excludes private
# targets), then strip the hash and print.
	@grep -E -h "^\w.*:.*##" $(MAKEFILE_LIST) | sed -e 's/\(.*\):.*##\(.*\)/\1	\2/'

install: ## Install the project.
	$(MAKE) _dc_compile

	@echo "Installing"
	docker compose --env-file .env.docker.local -f docker-compose.yml pull
	docker compose --env-file .env.docker.local -f docker-compose.yml up --force-recreate --detach --remove-orphans

	@echo "Waiting for database to be ready"
	sleep 10

	@echo "Initialize the database"
	docker compose --env-file .env.docker.local -f docker-compose.yml exec api bin/console doctrine:schema:create

	@echo "Clearing the cache"
	$(MAKE) cc

	@echo "Create jwt key pair"
	docker compose --env-file .env.docker.local -f docker-compose.yml exec api bin/console lexik:jwt:generate-keypair --skip-if-exists
	
	$(MAKE) tenant_add

	@echo "CREATE AN ADMIN USER. CHOOSE THE TENANT YOU JUST CREATED."
	$(MAKE) user_add

	$(MAKE) _show_notes


reinstall: ## Reinstall from scratch. Removes the database, all containers and volumes.
	$(MAKE) down
	$(MAKE) install

down:  ## Remove all containers and volumes.
	$(MAKE) stop 
	docker compose --env-file .env.docker.local -f docker-compose.yml down -v

up:  ## Take the whole environment up without altering the existing state of the containers.
	docker compose --env-file .env.docker.local -f docker-compose.yml up -d

stop: ## Stop all containers without altering anything else.
	docker compose --env-file .env.docker.local -f docker-compose.yml stop

tenant_add: ## Add a new tenant group
	@echo ""
	@echo "Add a tenant"
	@echo "===================================================="
	@echo "A tenant is a group of users that share the same configuration. F. ex. IT, Library, Schools etc."
	@echo "You have to provide tenant id, tenant title and optionally a description."
	@echo "===================================================="
	@echo ""
	docker compose --env-file .env.docker.local -f docker-compose.yml exec -T api bin/console app:tenant:add

user_add: ## Add a new user (editor or admin)
	@echo ""
	@echo "Add a user"
	@echo "===================================================="
	@echo "You have to provide email, password, full name, role (editor or admin) and the tenant id."
	@echo "===================================================="
	@echo ""
	docker compose --env-file .env.docker.local -f docker-compose.yml exec -T api bin/console app:user:add

logs: ## Follow docker logs from the containers
	docker compose --env-file .env.docker.local -f docker-compose.yml logs -f --tail=50

cc: ## Clear the cache
	docker compose --env-file .env.docker.local -f docker-compose.yml exec api bin/console cache:clear

# =============================================================================
# HELPERS
# =============================================================================
# These targets are usually not run manually.

_show_notes:
	@echo ""
	@echo "===================================================="
	@echo "OS2display now is available via the URLs below"
	@echo "===================================================="
	@echo "Admin: https://<your-domain>/admin"
	@echo "Screen: https://<your-domain>/screen"
	@echo "===================================================="
	@echo ""
	
_dc_compile:
	docker compose --env-file .env.docker.local --env-file mariadb/.env.database.local -f docker-compose.server.yml -f docker-compose.mariadb.yml -f docker-compose.traefik.yml config > docker-compose.yml
	


