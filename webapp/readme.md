docker compose down && docker compose build && docker compose up -d

docker compose down
docker compose build --no-cache --pull
docker compose up -d


pro test proti simulátoru API ve stejném docker hostu nezapomeň propojit sítě:
# spoj sítě, pokud si chceš pingnout z apky, která je taky hostovaná v dockeru...
docker network create solax-net
docker network connect solax-net solax-sim
docker network connect solax-net solax-web


> ⚡️ Ekologické upozornění:  
> náhvrh rozhraní a code review dělala AI:
> Při vývoji této aplikace bylo pravděpodobně spotřebováno více energie GPU,  
> než kolik vaše FVE vyrobí za pár dnů.  
>  
> A 💚

