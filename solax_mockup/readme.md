napodobuje solax invertor api: při každém volání dává zpět odpověd jako solax X G4....
ale data si bere ze souboru data.json: vždy každý další řádek a tak pořád dokola...

# build
docker build -t solax-sim:latest .
docker build --no-cache -t solax-sim:latest .

# run (publikuje port 8081 na hostu)
docker run -d --name solax-sim -p 8081:80 solax-sim:latest

# run devel (s volume mounty - rovnou můžeme měnit php  data.json za běhu) 
docker run -d --name solax-sim -p 8081:80 \
  -v "$(pwd)/index.php":/var/www/html/solax.php:rw \
  -v "$(pwd)/data.json":/var/www/html/data.json:rw \
  solax-sim:latest

# stop container
docker stop solax-sim

# remove kontejner
docker rm solax-sim


# rebuild
cd solax_mockup && \
docker stop solax-sim && docker rm solax-sim && docker run -d --name solax-sim -p 8081:80 solax-sim:latest && docker run -d --name solax-sim -p 8081:80 solax-sim:latest && \
cd ..
