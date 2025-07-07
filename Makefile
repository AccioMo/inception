.PHONY: all build up down clean fclean re

all: build up

build:
	@docker compose -f ./srcs/docker-compose.yml build

up:
	@docker compose -f ./srcs/docker-compose.yml up -d

down:
	@docker compose -f ./srcs/docker-compose.yml down

clean: down
	@docker system prune -a --force

fclean: clean
	@sudo rm -rf /home/${USER}/data

re: fclean all
