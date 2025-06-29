#!/bin/bash
docker pull itzg/minecraft-server
docker run -d -e EULA=TRUE -e MEMORY=6G -p 25565:25565 --name minecraft-java --restart=always -v minecraft_data:/data itzg/minecraft-server
