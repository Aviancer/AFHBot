# Twitch.tv / Discord community bot

Configurable commands and utility bot for Aviancer's streams and community. Allows reactives for Twitch chat as well as people to manage their own groups on Discord.
Can also be extended for cross-platform functionality.

# Building docker image

Run `make` to build afhbot.  

# Initial setup

## Create a config file

Create a config file based on the `templates/config.yml` template. This should be saved outside the Docker image and provided at `/app/data/config.yml` through a bind mount.

## Registering Discord slash commands 
`bin/afhbot` needs to be given 'register' as argument to register slash commands on Discord. This needs to be done only once unless the commands are updated.

After this just run `bin/afhbot` under Docker without arguments and it will use the configuration file for all needed options.

## Unregistering Discord slash commands

Run `bin/afhbot` with 'unregister' as the argument.

# Running as non-root user (preferred)
Create a user and group called 'afhbot' on the host machine so that mounted config files can be accessed by the bot.

## Example Docker command 

```docker run --name afhbot -d --restart unless-stopped --mount type=bind,source=/etc/afhbot,target=/app/data afhbot:latest```

