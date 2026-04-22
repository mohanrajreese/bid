.PHONY: up down restart logs setup migrate reset console test shell help

# Default target
help:
	@echo "Available commands:"
	@echo "  up      	- Start containers in the background"
	@echo "  down    	- Stop and remove containers"
	@echo "  restart 	- Restart the web container"
	@echo "  logs    	- Show logs from the web container"
	@echo "  setup   	- Run initial setup (deps, migrations, assets)"
	@echo "  migrate 	- Run database migrations"
	@echo "  reset   	- Reset database (drop, create, migrate, seed)"
	@echo "  console 	- Open IEx console in the web container"
	@echo "  test    	- Run tests"
	@echo "  shell   	- Open a shell in the web container"

up:
	sudo docker compose up

down:
	sudo docker compose down

restart:
	sudo docker compose restart web

logs:
	sudo docker compose logs -f web

setup:
	sudo docker compose run --rm web sh -c "mix deps.get && mix ecto.setup && mix assets.setup"

migrate:
	sudo docker compose run --rm web mix ecto.migrate

reset:
	sudo docker compose run --rm web mix ecto.reset

console:
	sudo docker compose exec web iex -S mix

test:
	sudo docker compose run --rm web mix test

shell:
	sudo docker compose exec web bash
